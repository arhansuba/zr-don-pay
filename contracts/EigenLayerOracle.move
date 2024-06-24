module EigenLayerOracle {
    use std::signer;
    use std::vector;
    use std::string;
    use std::option;
    use std::error;
    use std::event;
    use std::table;

    const ERR_REQUEST_NOT_FOUND: u64 = 1;
    const ERR_REQUEST_ALREADY_COMPLETED: u64 = 2;
    const ERR_VALIDATOR_NOT_FOUND: u64 = 3;
    const ERR_INSUFFICIENT_STAKE: u64 = 4;
    const ERR_UNAUTHORIZED_ACCESS: u64 = 5;

    struct DataRequest {
        id: u64,
        data_type: string::String,
        requester: address,
        completed: bool,
        data: string::String,
        validators: vector<address>,
    }

    struct Validator {
        id: u64,
        validator_address: address,
        stake: u64,
    }

    struct DataRequestHistory {
        requests: vector<DataRequest>,
    }

    resource struct Oracle {
        request_counter: u64,
        requests: table::Table<u64, DataRequest>,
        validators: table::Table<address, Validator>,
    }

    event RequestCreated {
        id: u64,
        data_type: string::String,
        requester: address,
    }

    event DataSubmitted {
        request_id: u64,
        validator: address,
        data: string::String,
    }

    public fun initialize(admin: &signer) {
        let oracle = Oracle {
            request_counter: 0,
            requests: table::new<u64, DataRequest>(),
            validators: table::new<address, Validator>(),
        };
        move_to(admin, oracle);
    }

    public fun register_validator(admin: &signer, validator_address: address, stake: u64) {
        let oracle = borrow_global_mut<Oracle>(signer::address_of(admin));
        let validator = Validator {
            id: oracle.validators.size(),
            validator_address,
            stake,
        };
        table::add(&mut oracle.validators, validator_address, validator);
    }

    public fun request_data(requester: &signer, data_type: string::String): u64 {
        let oracle = borrow_global_mut<Oracle>(signer::address_of(requester));
        let id = oracle.request_counter;
        let request = DataRequest {
            id,
            data_type: data_type.clone(),
            requester: signer::address_of(requester),
            completed: false,
            data: string::String::empty(),
            validators: vector::empty<address>(),
        };
        table::add(&mut oracle.requests, id, request);
        oracle.request_counter = id + 1;
        event::emit<RequestCreated>(&RequestCreated { id, data_type, requester: signer::address_of(requester) });
        id
    }

    public fun submit_data(validator: &signer, request_id: u64, data: string::String) {
        let oracle = borrow_global_mut<Oracle>(signer::address_of(validator));
        let validator_address = signer::address_of(validator);
        let request = table::borrow_mut(&mut oracle.requests, request_id);

        // Ensure the request is valid and not completed
        assert!(option::is_some(&option::borrow(&request)), ERR_REQUEST_NOT_FOUND);
        assert!(!request.completed, ERR_REQUEST_ALREADY_COMPLETED);

        // Ensure the validator is registered
        let validator = table::borrow(&oracle.validators, validator_address);
        assert!(option::is_some(&option::borrow(&validator)), ERR_VALIDATOR_NOT_FOUND);

        // Ensure the validator has sufficient stake
        assert!(validator.stake >= 10, ERR_INSUFFICIENT_STAKE);

        // Add the validator to the list of validators for this request
        vector::push_back(&mut request.validators, validator_address);
        request.data = data.clone();
        request.completed = true;

        // Emit event for data submission
        event::emit<DataSubmitted>(&DataSubmitted { request_id, validator: validator_address, data });
    }

    public fun get_request(requester: address, request_id: u64): &DataRequest {
        let oracle = borrow_global<Oracle>(requester);
        table::borrow(&oracle.requests, request_id)
    }

    public fun get_validator(validator_address: address): &Validator {
        let oracle = borrow_global<Oracle>(validator_address);
        table::borrow(&oracle.validators, validator_address)
    }

    public fun list_requests(): vector<DataRequest> {
        let oracle = borrow_global<Oracle>(signer::address_of(oracle));
        let mut requests = vector::empty<DataRequest>();
        let keys = table::keys(&oracle.requests);
        for key in keys {
            let request = table::borrow(&oracle.requests, *key);
            vector::push_back(&mut requests, *request);
        }
        requests
    }

    // Helper functions to save and borrow data requests
    fun save_request(id: u64, request: DataRequest) {
        // Save the request in a global storage map (omitted for brevity)
    }

    fun borrow_request(id: u64): &mut DataRequest {
        // Borrow the request from the global storage map (omitted for brevity)
    }

    fun generate_id(): u64 {
        // Generate a unique ID (omitted for brevity)
    }
}
