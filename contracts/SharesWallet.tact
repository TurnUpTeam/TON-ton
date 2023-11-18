import "@stdlib/deploy";

message UpdateBalance {
    amount: Int as uint16;
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
        require(sender() == self.keysContract, "Forbidden");
        if (msg.incr) {
            self.balance = self.balance + msg.amount;
        } else {
            require(self.balance >= msg.amount, "Insufficient balance");
            self.balance = self.balance + msg.amount;
        }
    }


}

