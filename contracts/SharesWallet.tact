import "@stdlib/deploy";

message UpdateBalance {
    queryId: Int as uint64;
    balance: Int as uint16;
    holder: Address;
    amount: Int as uint16;
    increment: Bool;
}

message BalanceUpdated {
    queryId: Int as uint64;
}

contract SharesWallet with Deployable {

    // TODO tune the following constants
    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    subject: Address;
    holder: Address;
    sharesContract: Address;
    balance: Int as uint16 = 0;

    init(holder: Address, subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the Keys contract");
        self.holder = holder;
        self.subject = subject;
        self.sharesContract = sharesContract;
    }

    receive(msg: UpdateBalance) {
        // dump("SharesWallet:UpdateBalance");
        let ctx: Context = context();
        // dump("Update balance");
        // dump(self.balance);
        // dump(msg.balance);
        // dump(msg.amount);
        // dump(msg.increment);
        require(sender() == self.sharesContract, "Forbidden");
        require(self.balance == msg.balance, "Balance mismatch");
        if (msg.increment) {
            self.balance = self.balance + msg.amount;
        } else {
            if (msg.holder == self.subject) {
                require(msg.amount < self.balance, "Subject cannot sell last key");
            } else {
                require(msg.amount <= self.balance, "Insufficient balance");
            }
            self.balance = self.balance - msg.amount;
        }
        // dump("balance after");
        // dump(self.balance);
        let remain: Int = self.estimateRestValue() - context().readForwardFee();
        send(SendParameters{
            to: self.sharesContract,
            value: remain,
            bounce: false,
            mode: SendPayGasSeparately,
            body: BalanceUpdated{
                queryId: msg.queryId
            }.toCell()
        });
    }

    inline fun estimateRestValue(): Int {
        let balance: Int = myBalance();
        let storageFee: Int = self.minTonsForStorage - min(balance, self.minTonsForStorage);
        return balance - (storageFee + self.gasConsumption);
    }

    get fun balance(): Int {
        return self.balance;
    }

}

