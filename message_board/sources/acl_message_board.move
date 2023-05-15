module message_board::acl_mb {
    use std::signer;
    use std::vector;
    use std::acl::Self;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    const EACCOUNT_NOT_IN_ACL: u64 = 1;
    const ECANNOT_REMOVE_ADMIN_FROM_ACL: u64 = 2;

    struct ACLBasedMB has key {
        participants: acl::ACL,
        pinned_post: vector<u8>
    }

    struct MessageChangeEventHandle has key {
        change_events: EventHandle<MessageChangeEvent>
    }

    struct MessageChangeEvent has store, drop {
        message: vector<u8>,
        participant: address
    }

    public entry fun message_board_init(account: &signer) {
        // new message board
        let board = ACLBasedMB {
            participants: acl::empty(),
            pinned_post: vector::empty<u8>()
        };
        // add signer to acl
        acl::add(&mut board.participants, signer::address_of(account));
        // move ACLBasedMB and MessageChangeEventHandle resources under signer
        move_to(account, board);
        move_to(account, MessageChangeEventHandle {
            change_events: account::new_event_handle<MessageChangeEvent>(account)
        })
    }

    public fun view_message(board_addr: address): vector<u8> acquires ACLBasedMB {
        let post = borrow_global<ACLBasedMB>(board_addr).pinned_post;
        copy post
    }

    // board owner add user to acl
    public entry fun add_participant(account: &signer, participant: address) acquires ACLBasedMB {
        let board = borrow_global_mut<ACLBasedMB>(signer::address_of(account));
        acl::add(&mut board.participants, participant);
    }

    // remove user from acl
    public entry fun remove_participant(account: signer, participant: address) acquires ACLBasedMB {
        let board = borrow_global_mut<ACLBasedMB>(signer::address_of(&account));
        assert!(signer::address_of(&account) != participant, ECANNOT_REMOVE_ADMIN_FROM_ACL);
        acl::remove(&mut board.participants, participant);
    }

    // pin message to board
    public entry fun send_pinned_message(
        account: &signer, board_addr: address, message: vector<u8>
    ) acquires ACLBasedMB, MessageChangeEventHandle {
        // check if account is in acl
        let board = borrow_global<ACLBasedMB>(board_addr);
        assert!(acl::contains(&board.participants, signer::address_of(account)), EACCOUNT_NOT_IN_ACL);

        // write message to board
        let board = borrow_global_mut<ACLBasedMB>(board_addr);
        board.pinned_post = message;

        // emit message change event
        let send_acct = signer::address_of(account);
        let event_handle = borrow_global_mut<MessageChangeEventHandle>(board_addr);
        event::emit_event<MessageChangeEvent>(
            &mut event_handle.change_events,
            MessageChangeEvent {
                message,
                participant: send_acct
            }
        );
    }

    // send message to board without pinning it 
    public entry fun send_message_to(
        account: signer, board_addr: address, message: vector<u8>
    ) acquires MessageChangeEventHandle {
        // emit message event
        let event_handle = borrow_global_mut<MessageChangeEventHandle>(board_addr);
        event::emit_event<MessageChangeEvent>(
            &mut event_handle.change_events,
            MessageChangeEvent {
                message,
                participant: signer::address_of(&account)
            }
        );
    }
}
