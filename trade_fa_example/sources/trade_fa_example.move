module TradeFACoin::trade_fa_example {
    use FACoin::fungible_asset_example_1;
    use FACoin::fungible_asset_example_2;
    
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use std::signer;

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
    }
    fun init_module(resource_signer: &signer) {
        // Retrieve the resource signer's signer capability and store it within the `ModuleData`.
        // Note that by calling `resource_account::retrieve_resource_account_cap` to retrieve the resource account's signer capability,
        // we rotate th resource account's authentication key to 0 and give up our control over the resource account. Before calling this function,
        // the resource account has the same authentication key as the source account so we had control over the resource account.
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);

        // Store the token data id and the resource account's signer capability within the module, so we can programmatically
        // sign for transactions in the `mint_event_ticket()` function.
        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap,
        });
        
    }

    public entry fun trade(from: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@TradeFACoin);
        // Create a signer of the resource account from the signer capability stored in this module.
        // Using a resource account and storing its signer capability within the module allows the module to programmatically
        // sign transactions on behalf of the module.
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        fungible_asset_example_1::transfer(from, @TradeFACoin, amount);
        fungible_asset_example_2::transfer(&resource_signer, signer::address_of(from), amount);
    }

}