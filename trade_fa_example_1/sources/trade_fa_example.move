module TradeFACoin::trade_fa_example {
    
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;

    const ASSET_SYMBOL: vector<u8> = b"FA-Trade";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
    }
    fun init_module(resource_signer: &signer) {
        let constructor_ref = &object::create_named_object(resource_signer, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"FA-Trade"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );// <:!:initialize

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

    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@TradeFACoin, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }
    
    fun get_resource_signer() : signer acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@TradeFACoin);
        // Create a signer of the resource account from the signer capability stored in this module.
        // Using a resource account and storing its signer capability within the module allows the module to programmatically
        // sign transactions on behalf of the module.
        account::create_signer_with_capability(&module_data.signer_cap)
    }

    /// Mint as the owner of metadata object.
    fun mint(to: address, amount: u64) acquires ModuleData, ManagedFungibleAsset {
        let resource_signer = get_resource_signer();
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(&resource_signer, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }

    public entry fun transfer(from: &signer, to: address, asset_address: address, amount: u64) {
        let from_address = signer::address_of(from);
        let asset = object::address_to_object<Metadata>(asset_address);
        let from_wallet = primary_fungible_store::primary_store(from_address, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::transfer(from, from_wallet, to_wallet, amount);
    }

    public entry fun trade(from: &signer, asset_address: address, amount: u64) acquires ModuleData, ManagedFungibleAsset {
        transfer(from, @TradeFACoin, asset_address, amount);
        let from_address = signer::address_of(from);
        mint(from_address, amount);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }
}