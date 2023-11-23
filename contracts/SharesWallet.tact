import "@stdlib/deploy";

message UpdateBalance {
    queryId: Int as uint64;
    amount: Int as uint16;
    increment: Bool;
}

message UpdateSupplyAndBalance {
    queryId: Int as uint64;
    subject: Address;
    holder: Address;
    amount: Int as uint16;
    balance: Int as uint16;
    increment: Bool;
    price: Int as coins;
    protocolFee: Int as coins;
    subjectFee: Int as coins;
}

message WalletUpdated {
    queryId: Int as uint64;
    subject: Address;
    holder: Address;
    amount: Int as uint16;
    balance: Int as uint16;
    increment: Bool;
    price: Int as coins;
    protocolFee: Int as coins;
    subjectFee: Int as coins;
}

message WalletError {
    queryId: Int as uint64;
    msg: String;
}

message BalanceUpdated {
    queryId: Int as uint64;
    balance: Int as uint16;
    increment: Bool;
}

message GetBalance {
    queryId: Int as uint64;
    holder: Address;
    amount: Int as uint16;
    increment: Bool;
    remain: Int as coins;
    balance: Int as uint16;
}

contract SharesWallet with Deployable {

    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    subject: Address;
    holder: Address;
    sharesContract: Address;
    balance: Int as uint16 = 0;

    receive() {}

    init(holder: Address, subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the Keys contract");
        self.holder = holder;
        self.subject = subject;
        self.sharesContract = sharesContract;
    }

    receive(msg: UpdateBalance) {
        dump("SharesWallet:UpdateBalance");
        let ctx: Context = context();
        dump("Update balance");
        dump(ctx.value);
        require(sender() == self.sharesContract, "Forbidden");
        if (msg.increment) {
            self.balance = self.balance + msg.amount;
        } else {
            require(self.balance >= msg.amount, "Insufficient balance");
            self.balance = self.balance - msg.amount;
        }
        let remain: Int = self.estimateRestValue() - context().readForwardFee();
        send(SendParameters{
            to: self.sharesContract,
            value: remain,
            bounce: false,
            mode: SendPayGasSeparately,
            body: UpdateBalance{
                queryId: msg.queryId,
                amount: self.balance,
                increment: msg.increment
            }.toCell()
        });
    }

/*
    receive(msg: UpdateSupplyAndBalance) {
        require(sender() == self.sharesContract, "Forbidden");
        if (msg.increment) {
            self.balance = self.balance + msg.amount;
        } else {
            require(self.balance >= msg.amount, "Insufficient balance");
            self.balance = self.balance - msg.amount;
        }
        self.reply(WalletUpdated{
            subject: msg.subject,
           holder: self.holder,
           amount: msg.amount,
           increment: msg.increment,
           price: msg.price,
           protocolFee: msg.protocolFee,
           subjectFee: msg.subjectFee,
           balance: self.balance
        }.toCell());
    }

    receive(msg: GetBalance) {
        require(sender() == self.sharesContract, "Forbidden");
        self.reply(GetBalance{
            holder: msg.holder,
            amount: msg.amount,
            increment: msg.increment,
            remain: msg.remain,
            balance: self.balance
        }.toCell());
    }
*/

    /*inline fun _internal_transfer_excesses(ctx: Context, msg: UpdateSupplyAndBalance, remain: Int){
        if((msg.response_address != newAddress(0, 0)) && remain > 0){
            send(SendParameters{
                to: msg.response_address,
                value: remain,
                bounce: false,
                mode: SendIgnoreErrors,
                body: Excesses{
                    queryId: msg.queryId
                }.toCell()
            });
        }
    }*/

    inline fun estimateRestValue(): Int {
        let balance: Int = myBalance();
        let storageFee: Int = self.minTonsForStorage - min(balance, self.minTonsForStorage);
        return balance - (storageFee + self.gasConsumption);
    }

    get fun balance(): Int {
        return self.balance;
    }

}

