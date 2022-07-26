module StarcoinFramework::StakeToSBTPlugin {

    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::DAOSpace;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Option;
    use StarcoinFramework::InstallPluginProposalPlugin;

    const ERR_PLUGIN_USER_IS_MEMBER: u64 = 1001;
    const ERR_PLUGIN_HAS_STAKED: u64 = 1002;
    const ERR_PLUGIN_NOT_STAKE: u64 = 1003;
    const ERR_PLUGIN_STILL_LOCKED: u64 = 1004;
    const ERR_PLUGIN_CONFIG_INIT_REPEATE: u64 = 1005;
    const ERR_PLUGIN_ITEM_CANT_FOUND: u64 = 1006;

    struct StakeToSBTPlugin has drop {}

    public fun required_caps(): vector<DAOSpace::CapType> {
        let caps = Vector::singleton(DAOSpace::proposal_cap_type());
        Vector::push_back(&mut caps, DAOSpace::member_cap_type());
        Vector::push_back(&mut caps, DAOSpace::modify_config_cap_type());
        caps
    }

    struct Stake<phantom DaoT, phantom TokenT> has key, store {
        id: u64,
        token: Token::Token<TokenT>,
        stake_time: u64,
        // The timestamp when user stake
        lock_time: u64,
        // How long where the user locked
        weight: u64,
        // Which multiplier by the user stake
        sbt_amount: u128,
        //  The SBT amount that user swap in the token
    }

    struct StakeList<phantom DaoT, phantom TokenT> has key, store {
        items: vector<Stake<DaoT, TokenT>>,
        next_id: u64
    }

    struct LockWeightConfig<phantom DaoT, phantom TokenT> has copy, store, drop {
        weight_vec: vector<LockWeight<DaoT, TokenT>>
    }

    struct LockWeight<phantom DaoT, phantom TokenT> has copy, drop, store {
        lock_time: u64,
        weight: u64,
    }

    struct AcceptTokenCap<phantom DaoT, phantom TokenT> has store {}

    /// Initialize config
    public fun init_config<DaoT: store, TokenT: store>(cap: AcceptTokenCap<DaoT, TokenT>) {
        let AcceptTokenCap<DaoT, TokenT> {} = cap;

        assert!(
            !DAOSpace::exists_custom_config<DaoT, LockWeightConfig<DaoT, TokenT>>(),
            Errors::invalid_state(ERR_PLUGIN_CONFIG_INIT_REPEATE)
        );

        let witness = StakeToSBTPlugin {};
        let modify_config_cap =
            DAOSpace::acquire_modify_config_cap<DaoT, StakeToSBTPlugin>(&witness);

        DAOSpace::set_custom_config<
            DaoT,
            StakeToSBTPlugin,
            LockWeightConfig<DaoT, TokenT>
        >(&mut modify_config_cap, LockWeightConfig<DaoT, TokenT> {
            weight_vec: Vector::empty<LockWeight<DaoT, TokenT>>()
        });
    }

    public fun stake<DaoT: store, TokenT: store>(sender: &signer,
                                                 token: Token::Token<TokenT>,
                                                 lock_time: u64) acquires StakeList {
        let sender_addr = Signer::address_of(sender);
        assert!(DAOSpace::is_member<DaoT>(sender_addr), Errors::invalid_state(ERR_PLUGIN_USER_IS_MEMBER));

        if (!exists<StakeList<DaoT, TokenT>>(sender_addr)) {
            move_to(sender, StakeList<DaoT, TokenT> {
                items: Vector::empty(),
                next_id: 0
            });
        };

        // Increase SBT
        let witness = StakeToSBTPlugin {};
        let cap = DAOSpace::acquire_member_cap<DaoT, StakeToSBTPlugin>(&witness);
        let weight_opt = get_sbt_weight<DaoT, TokenT>(lock_time);
        let weight = if (Option::is_none(&weight_opt)) {
            1
        } else {
            Option::destroy_some(weight_opt)
        };

        let sbt_amount = (weight as u128) * Token::value<TokenT>(&token);
        DAOSpace::increase_member_sbt(&cap, sender_addr, sbt_amount);

        let stake_list = borrow_global_mut<StakeList<DaoT, TokenT>>(sender_addr);
        let id = stake_list.next_id + 1;
        Vector::push_back(
            &mut stake_list.items,
            Stake<DaoT, TokenT> {
                id,
                token,
                lock_time,
                stake_time: Timestamp::now_seconds(),
                weight,
                sbt_amount
            });
        stake_list.next_id = id;
    }

    /// Unstake from staking
    public fun unstake_by_id<DaoT: store, TokenT: store>(id: u64, member: address)
    : Token::Token<TokenT> acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<DaoT, TokenT>>(member);
        let item_index = find_item(id, &stake_list.items);

        // Check item in item container
        assert!(!Option::is_some(&item_index), Errors::invalid_state(ERR_PLUGIN_ITEM_CANT_FOUND));

        let poped_item =
            Vector::remove(&mut stake_list.items, Option::destroy_some(item_index));

        unstake_item(member, poped_item)
    }

    /// Unstake all staking items from member address,
    /// No care whether the user is member or not
    public fun unstake_all<DaoT: store, TokenT: store>(member: address) acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<DaoT, TokenT>>(member);
        let len = Vector::length(&mut stake_list.items);

        let idx = 0;
        while (idx < len) {
            let item = Vector::remove(&mut stake_list.items, idx);
            Account::deposit(member, unstake_item<DaoT, TokenT>(member, item));
            idx = idx + 1;
        };
    }

    /// Unstake a item from a item object
    fun unstake_item<DaoT: store, TokenT: store>(member: address, item: Stake<DaoT, TokenT>): Token::Token<TokenT> {
        let Stake<DaoT, TokenT> {
            id: _,
            token,
            lock_time,
            stake_time,
            weight: _,
            sbt_amount,
        } = item;

        assert!((Timestamp::now_seconds() - stake_time) > lock_time, Errors::invalid_state(ERR_PLUGIN_STILL_LOCKED));

        // Decrease SBT by weight
        if (DAOSpace::is_member<DaoT>(member)) {
            let witness = StakeToSBTPlugin {};
            let cap = DAOSpace::acquire_member_cap<DaoT, StakeToSBTPlugin>(&witness);
            DAOSpace::decrease_member_sbt(&cap, member, sbt_amount);
        };
        token
    }

    fun get_sbt_weight<DaoT: store, TokenT: store>(lock_time: u64): Option::Option<u64> {
        let config = DAOSpace::get_custom_config<DaoT, LockWeightConfig<DaoT, TokenT>>();
        let c = &mut config.weight_vec;
        let len = Vector::length(c);
        let idx = 0;
        while (idx < len) {
            let e = Vector::borrow(c, idx);
            if (e.lock_time == lock_time) {
                return Option::some(e.weight)
            };
            idx = idx + 1;
        };

        Option::none<u64>()
    }

    fun set_sbt_weight<DaoT: store, TokenT: store>(lock_time: u64, weight: u64) {
        let config = DAOSpace::get_custom_config<DaoT, LockWeightConfig<DaoT, TokenT>>();
        let c = &mut config.weight_vec;
        let len = Vector::length(c);
        let idx = 0;
        while (idx < len) {
            let borrowed_c = Vector::borrow_mut(c, idx);
            if (borrowed_c.lock_time == lock_time) {
                borrowed_c.weight = weight;
                return
            };
            idx = idx + 1;
        };

        let witness = StakeToSBTPlugin {};
        let modify_config_cap =
            DAOSpace::acquire_modify_config_cap<DaoT, StakeToSBTPlugin>(&witness);
        DAOSpace::set_custom_config<
            DaoT,
            StakeToSBTPlugin,
            LockWeightConfig<DaoT, TokenT>
        >(&mut modify_config_cap, LockWeightConfig<DaoT, TokenT> {
            weight_vec: *&config.weight_vec
        });
    }

    fun find_item<DaoT: store, TokenT: store>(id: u64, c: &vector<Stake<DaoT, TokenT>>): Option::Option<u64> {
        let len = Vector::length(c);
        let idx = 0;
        while (idx < len) {
            let item = Vector::borrow(c, idx);
            if (item.id == id) {
                return Option::some(idx)
            };
            idx = idx + 1;
        };
        Option::none()
    }

    /// Create proposal that to specific a weight for a locktime
    public(script) fun create_weight_proposal<DaoT: store, TokenT: store>(sender: signer,
                                                                          lock_time: u64,
                                                                          weight: u64,
                                                                          action_delay: u64) {
        let witness = StakeToSBTPlugin {};

        let cap =
            DAOSpace::acquire_proposal_cap<DaoT, StakeToSBTPlugin>(&witness);
        DAOSpace::create_proposal(&cap, &sender, LockWeight<DaoT, TokenT> {
            lock_time,
            weight,
        }, action_delay);
    }

    public(script) fun execute_weight_proposal<DaoT: store, TokenT: store>(sender: signer,
                                                                           proposal_id: u64) {
        let witness = StakeToSBTPlugin {};
        let proposal_cap =
            DAOSpace::acquire_proposal_cap<DaoT, StakeToSBTPlugin>(&witness);

        let LockWeight<DaoT, TokenT> {
            lock_time,
            weight
        } = DAOSpace::execute_proposal<
            DaoT,
            StakeToSBTPlugin,
            LockWeight<DaoT, TokenT>
        >(&proposal_cap, &sender, proposal_id);

        set_sbt_weight<DaoT, TokenT>(lock_time, weight);
    }

    /// Create proposal that to accept a token type, which allow user to convert amount of token to SBT
    public(script) fun create_token_accept_proposal<DaoT: store, TokenT: store>(sender: signer,
                                                                                action_delay: u64) {
        let witness = StakeToSBTPlugin {};

        let cap =
            DAOSpace::acquire_proposal_cap<DaoT, StakeToSBTPlugin>(&witness);
        DAOSpace::create_proposal(&cap, &sender, AcceptTokenCap<DaoT, TokenT> {}, action_delay);
    }

    public(script) fun execute_token_accept_proposal<DaoT: store, TokenT: store>(sender: signer,
                                                                                 proposal_id: u64) {
        let witness = StakeToSBTPlugin {};
        let proposal_cap =
            DAOSpace::acquire_proposal_cap<DaoT, StakeToSBTPlugin>(&witness);

        let cap = DAOSpace::execute_proposal<
            DaoT,
            StakeToSBTPlugin,
            AcceptTokenCap<DaoT, TokenT>
        >(&proposal_cap, &sender, proposal_id);

        init_config(cap);
    }

    public(script) fun install_plugin_proposal<DaoT: store>(sender: signer, action_delay: u64) {
        InstallPluginProposalPlugin::create_proposal<DaoT, StakeToSBTPlugin>(&sender, required_caps(), action_delay);
    }
}