module ToDoList::todolist {
    use std::signer;
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};

    const E_NOT_INITIALIZED: u64 = 0;
    const ETASK_DOESNT_EXIST: u64 = 1;
    const ETASK_IS_COMPLETED: u64 = 2;

    struct TodoList has key {
        tasks: Table<u64, Task>,
        task_counter: u64,
        set_task_event: event::EventHandle<Task>
    }

    struct Task has store, drop, copy {
        task_id: u64,
        address: address,
        content: String,
        completed: bool
    }

    public entry fun create_list(account: &signer) {
        // init new todo list
        let todo_list = TodoList {
            tasks: table::new(),
            task_counter: 0,
            set_task_event: account::new_event_handle<Task>(account)
        };
        // move TodoList resource under signer account
        move_to(account, todo_list);
    }

    public entry fun create_task(account: &signer, content: String) acquires TodoList {
        let addr = signer::address_of(account);
        // check list exists for signer
        assert!(exists<TodoList>(addr), E_NOT_INITIALIZED);
        // get TodoList resource
        let todo_list = borrow_global_mut<TodoList>(addr);
        // create new task
        let counter = todo_list.task_counter + 1;
        let new_task = Task {
            task_id: counter,
            address: addr,
            content,
            completed: false
        };
        // add new task to TodoList.tasks table
        table::upsert(&mut todo_list.tasks, counter, new_task);
        // update TodoList.counter 
        todo_list.task_counter = counter;
        // fire event
        event::emit_event<Task>(
            &mut borrow_global_mut<TodoList>(addr).set_task_event,
            new_task
        );
    }

    public entry fun complete_task(account: &signer, task_id: u64) acquires TodoList {
        let addr = signer::address_of(account);
        // check list exists for signer
        assert!(exists<TodoList>(addr), E_NOT_INITIALIZED);
        // get TodoList resource
        let todo_list = borrow_global_mut<TodoList>(addr);
        // check list has this task_id
        assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        // get Task
        let task_record = table::borrow_mut(&mut todo_list.tasks, task_id);
        // check task is not completed
        assert!(task_record.completed == false, ETASK_IS_COMPLETED);
        // update task as completed
        task_record.completed = true;
    }
}