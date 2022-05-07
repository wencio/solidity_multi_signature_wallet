// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MultiSigWallet {
    // first we define the events that are fired when you deposit ETH to this contract 
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

// Store  owners in an array of Owners 
    address[] public owners;
// If an address is a owner of the multisig wallet returns true 
    mapping(address => bool) public isOwner;
// We storage, in an state variable the number of approvals required for a Transaction
    uint public numConfirmationsRequired;
// Struct to define the transaccion .. , address to; will be the address where the transaction is executed ..

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // Mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;

    // Storage all transactions
    Transaction[] public transactions;

// RequireS that the msg.sender, has to be in the map of owners (isOwner Map)
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        // we allow the execution of the rest of the function
        _;
    }

// We check the index of the transaccion, verifing, if the transaccion exits, comparing it,
// with the transaction.length of the array of transaccions 

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

//  We check that the transaction is not yet already executed 
// Using the array of transactions and the executed attribute of the transaction struct 
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

// We check, if the transaction, is not already approved/confirmed 
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

// creating the constructor: two parameters: first the array of owners and then the array of
// numbers of confirmattions requires to approve the transaccion 
  
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
       // Require that we have at least one owner 
        require(_owners.length > 0, "owners required");
    // 
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );
    // Saving the owners to the state variables 
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

    // Insert to the state mapping 
            isOwner[owner] = true;
    // Insert to the state array of owners 
            owners.push(owner);
        }
    // Setting the numbers of confirmation needed 
        numConfirmationsRequired = _numConfirmationsRequired;
    }
//--------------------------------------------------------------------
// We enable this multisig wallet to receive ETH
    receive() external payable {
// Emit the deposit event 
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
// function to submit the transaction .. onlyOwner modifier 

//----------------------------------------------------------------------
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }
//--------------------------------------------------------------------------
// We confirm the transaction cheking for modifiers : onlyOwner, txExists, notExecuted, notConfirmed....
    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    //--------------------------------------------------------------
    //We execute the transaction 

    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
       
        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

         Transaction storage transaction = transactions[_txIndex];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

//------------------------------------------------
// Revoke confirmation, not transaction, we check modifiers: onlyOwner,txExists,notExecuted
    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
