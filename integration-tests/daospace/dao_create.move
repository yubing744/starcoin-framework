//# init -n dev

//# faucet --addr alice --amount 10000000000

//# faucet --addr bob --amount 10000000000

//# block --author=0x3 --timestamp 900000

//# run --signers alice
script{
    use StarcoinFramework::DAOAccount;

    fun main(sender: signer){
        DAOAccount::create_account_entry(sender);
    }
}
// check: EXECUTED

//# view --address alice --resource 0x1::DAOAccount::DAOAccountCap

//# package
module 0xbf3a917cf4fb6425b95cc12763e6038b::XDAO {
    use StarcoinFramework::Option;
    use StarcoinFramework::DAOSpace;
    use StarcoinFramework::DAOAccount;
    use StarcoinFramework::Vector;

    struct X has store, drop {}
    
    struct Ext has store, drop {
        long_description: vector<u8>,
        purpose: vector<u8>,
        tags: vector<vector<u8>>,
        links: vector<vector<u8>>,
    }
    
    const NAME: vector<u8> = b"X";
    public (script) fun create_new_proposal_dao(
        sender: signer, 
        voting_delay: u64,
        voting_period: u64,
        voting_quorum_rate: u8,
        min_action_delay: u64,
        min_proposal_deposit: u128,)
    {
                
        let witness = X {};
        let config = DAOSpace::new_dao_config(
            voting_delay,
            voting_period,
            voting_quorum_rate,
            min_action_delay,
            min_proposal_deposit,
        );

        // create dao account
        let cap = DAOAccount::extract_dao_account_cap(&sender);
        DAOSpace::create_dao<X>(cap, *&NAME, Option::none<vector<u8>>(), Option::none<vector<u8>>(), b"ipfs://description", config);
        
        // ext info
        let tags = Vector::empty<vector<u8>>();
        Vector::push_back(&mut tags, b"tag1");
        
        let links = Vector::empty<vector<u8>>();
        Vector::push_back(&mut links, b"link1");

        let ext_info = Ext {
            long_description: b"xxx",
            purpose: b"xxx",
            tags: tags,
            links: links
        };

        let storage_cap = DAOSpace::acquire_storage_cap<X, X>(&witness);
        DAOSpace::save_to_storage<X, X, Ext>(&storage_cap, ext_info);

        // init member
        let member_cap = DAOSpace::acquire_member_cap<X, X>(&witness);
        DAOSpace::join_member_with_member_cap(&member_cap, &sender, Option::none<vector<u8>>(), Option::none<vector<u8>>(), 1);

        // offer member
        DAOSpace::issue_member_offer(&member_cap, @0xd310cC39b6E8b36E5729469FB2f80a10, Option::none<vector<u8>>(), Option::none<vector<u8>>(), 1);
    }
}

//# run --signers alice --args {{$.package[0].package_hash}}
script{
    use StarcoinFramework::DAOAccount;

    fun main(sender: signer, package_hash: vector<u8>){
        DAOAccount::submit_upgrade_plan_entry(sender, package_hash, 1, false);
    }
}
// check: EXECUTED

//# block --author=0x3 --timestamp 90240000

//# deploy {{$.package[0].file}} --signers bob

//# run --signers alice
script{
    use 0xbf3a917cf4fb6425b95cc12763e6038b::XDAO;

    fun main(sender: signer){
        XDAO::create_new_proposal_dao(sender, 1000, 1000, 1, 1000, 1000);
    }
}
// check: EXECUTED