import "@stdlib/deploy";

message UpdateBalance {
    amount: Int as uint16;
    incr: Bool;
}

message WalletError {
    msg: String;
}

message BalanceUpdated {
    balance: Int as uint16;
    incr: Bool;
}

contract SharesWallet with Deployable {
    subject: Address;
    owner: Address;
    keysContract: Address;
    balance: Int as uint16 = 0;

    receive() {}

    init(owner: Address, subject: Address, keysContract: Address) {
        require(sender() == keysContract, "Not the Keys contract");
        self.owner = owner;
        self.subject = subject;
        self.keysContract = keysContract;
    }

    receive(msg: UpdateBalance) {
        log("My contract is doing something important.");
        require(sender() == self.keysContract, "Forbidden");
        if (msg.incr) {
            self.balance = self.balance + msg.amount;
        } else if (owner == self.subject) {
            require(self.balance > msg.amount, "Subject cannot sell last key");
        } else {
            require(self.balance >= msg.amount, "Insufficient balance");            }
        }
    }

}

