import "@stdlib/deploy";

message UpdateBalance {
    amount: Int as uint16;
    increment: Bool;
}

message WalletError {
    msg: String;
}

message BalanceUpdated {
    balance: Int as uint16;
    increment: Bool;
}

message GetBalance {
    holder: Address;
    amount: Int as uint16;
    increment: Bool;
    remain: Int as coins;
    balance: Int as uint16;
}

contract SharesWallet with Deployable {
    subject: Address;
    holder: Address;
    keysContract: Address;
    balance: Int as uint16 = 0;

    receive() {}

    init(holder: Address, subject: Address, keysContract: Address) {
        require(sender() == keysContract, "Not the Keys contract");
        self.holder = holder;
        self.subject = subject;
        self.keysContract = keysContract;
    }

    receive(msg: UpdateBalance) {
        require(sender() == self.keysContract, "Forbidden");
        if (msg.increment) {
            self.balance = self.balance + msg.amount;
        } else {
            if (self.holder == self.subject) {
                require(self.balance > msg.amount, "Subject cannot sell last key");
            } else {
                require(self.balance >= msg.amount, "Insufficient balance");
            }
            self.balance = self.balance - msg.amount;
        }
    }

    receive(msg: GetBalance) {
        require(sender() == self.keysContract, "Forbidden");
        self.reply(GetBalance{
            holder: msg.holder,
            amount: msg.amount,
            increment: msg.increment,
            remain: msg.remain,
            balance: self.balance
        }.toCell());
    }

    get fun balance(): Int {
        return self.balance;
    }

}

