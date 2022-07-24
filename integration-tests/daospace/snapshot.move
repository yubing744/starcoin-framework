//# init --rpc http://barnard.seed.starcoin.org  --block-number 6201718

//# faucet --addr creator --amount 100000000000

//# call-api state.get_with_proof_by_root_raw ["0x6bfb460477adf9dd0455d3de2fc7f211/1/0x00000000000000000000000000000001::IdentifierNFT::IdentifierNFT<0x6bfb460477adf9dd0455d3de2fc7f211::SBTModule::DaoMember<0x6bfb460477adf9dd0455d3de2fc7f211::SBTModule::SbtTestDAO>,0x6bfb460477adf9dd0455d3de2fc7f211::SBTModule::DaoMemberBody<0x6bfb460477adf9dd0455d3de2fc7f211::SBTModule::SbtTestDAO>>","0xd5cd5dc44799c989a84b7d4a810259f373b13a9bf8ee21ecbed0fab264e2090d"]


//TODO how to convert the type.
//# run --signers creator --args {{$.call-api[0]}}
script{
    use StarcoinFramework::Debug;

    fun main(_sender: signer, snpashot_raw_proofs: vector<u8>){
        let expect_raw_proofs = x"0145016bfb460477adf9dd0455d3de2fc7f21101000000000000000664616f313031000a69616d67655f64617461005704000000000000640000000000000000000000000000000145020120cc969848619e507450ebf01437155ab5f2dbb554fe611cb71958855a1b2ec664012035f2374c333a51e46b62b693ebef25b9be2cefde8d156db08bff28f9a0b87742012073837fcf4e69ae60e18ea291b9f25c86ce8053c6ee647a2b287083327c67dd7e20dac300fb581a6df034a44a99e8eb1cd55c7dd8f0a9e78f1114a6b4eda01d834e0e2078179a07914562223d40068488a0d65673b3b2681642633dc33904575f8f070b20b7c2a21de200ca82241e5e480e922258591b219dd56c24c4d94299020ee8299a204f541db82477510f699c9d75dd6d8280639a1ec9d0b90962cbc0c2b06514a78b20cacfce99bb564cfb70eec6a61bb76b9d56eb1b626d7fa231338792e1f572a8df20da6c1337ca5d8f0fa18b2db35844c610858a710edac35206ef0bf52fd32a4ac920ef6fb8f82d32ca2b7c482b7942505e6492bffa3ed14dd635bae16a14b4ac32e6202ad7b36e08e7b5d208de8eec1ef1964dc8433ccca8ac4632f36054926e858ac32027d5ccc8aa57b964ad50334f62821188b89945ae999ad0bb31cdc16df1763f8120afa983813953d6aa9563db12d5e443c9e8114c3482867c95a661a240d6f0e0ec206466ac318f5d9deb7b64b12622a0f4bed2f19379667d18b6ccfeaa84171d812f20eb45021b7b39887925a5b49018cdc8ad44c14835a42e5775666315f4a3e0ba42204c2b365a78e4615873772a0f039a7326150472b4923d40640863dbe42a2351eb20825d0c21dd1105faf528934842419f8661d695fc72ec6ef8036f5d03359126d3205d806c027eecdfbc3960e68c5997718a0709a6079f96e1af3ffe21878ada2b830120fa60f8311936961f5e9dee5ccafaea83ed91c6eaa04a7dea0b85a38cf84d8564207ef6a85019523861474cdf47f4db8087e5368171d95cc2c1e57055a72ca39cb704208db1e4e4c864882bd611b1cda02ca30c43b3c7bc56ee7cb174598188da8b49ef2063b3f1e4f05973830ba40e0c50c4e59f31d3baa5643d19676ddbacbf797bf6b720b39d31107837c1751d439706c8ddac96f8c148b8430ac4f40546f33fb9871e4320fb0ad035780bb8f1c6481bd674ccad0948cd2e8e6b97c08e582f67cc26918fb3";
        Debug::print(&snpashot_raw_proofs);
        assert!(expect_raw_proofs == snpashot_raw_proofs, 8001);
    }
}
// check: EXECUTED