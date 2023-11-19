import "@stdlib/deploy";

import "./SharesWallet";

message FirstKeys {
    sender: Address;
    owner: Address;
    initialSupply: Int as uint16;
    price: Int as coins;
    protocolFee: Int as coins;
    subjectFee: Int as coins;
    value: Int as coins;
}

message CurrentSupply {
    holder: Address;
    amount: Int as uint16;
    incr: Bool;
    value: Int as uint64;
}

message UpdateSupplyAndBalance {
    holder: Address;
    amount: Int as uint16;
    incr: Bool;
    value: Int as uint64;
}

message Supply{
    subject: Address;
    holder: Address;
    supply: Int as uint16;
    amount: Int as uint16;
    incr: Bool;
    value: Int as uint64;
}

message UpdatedSupplyAndBalance {
    subject: Address;
    supply: Int as uint16;
    amount: Int as uint16;
    incr: Bool;
    value: Int as uint64;
    price: Int as uint64;
    protocolFee: Int as uint64;
    subjectFee: Int as uint;
}

message RevertError {
    sender: Address;
    value: Int as coins;
}

contract SharesKey with Deployable {
    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    subject: Address;
    sharesContract: Address; // Shares contract
    supply: Int as uint16 = 0;

    init(subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the shares contract");
        self.subject = subject;
        self.sharesContract = sender();
    }

    receive() {}

    inline fun _refund_user(value: Int): Address {
        let ctx: Context = context();
        send(SendParameters{
         to: self.subject,
         value: _estimate_rest_value(ctx.balance),
         bounce: true,
         mode: SendRemainingValue
        });
    }

    inline fun _estimate_rest_value(remain: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - remain;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        return remain - (storageFee + self.gasConsumption);
    }

    receive(msg: FirstKeys) {
        if (self.supply > 0) {

            log("My contract is doing something important.");
            _refund_user();
        } else {
            let ctx: Context = context();
            require(ctx.sender == self.sharesContract, "Forbidden");
            let initCode: StateInit = self.calculate_sharesWallet_init(msg.owner);
            self.supply = msg.initialSupply;
            send(SendParameters{
             to: contractAddress(initCode),
             value: 0,
             bounce: true,
             mode: SendRemainingValue + SendIgnoreErrors,
             body: UpdateBalance{
                 amount: msg.initialSupply,
                 incr: true
             }.toCell(),
             code: initCode.code,
             data: initCode.data
            });
        }
    }

    receive(msg: UpdateSupplyAndBalance) {
        require(self.supply > 0, "Not initialized");
        require(context().sender == self.sharesContract, "Forbidden");
        if (msg.incr) {
            self.supply = self.supply + msg.amount;
        } else {
            require(self.supply >= msg.amount, "Insufficient balance");
            self.supply = self.supply + msg.amount;
        }
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        send(SendParameters{
         to: contractAddress(initCode),
         value: 0,
         mode: SendRemainingValue + SendIgnoreErrors,
         body: UpdateBalance{
             amount: msg.amount,
             incr: true
         }.toCell()
        });
    }

    receive(msg: CurrentSupply) {
        require(self.supply > 0, "Not initialized");
        require(context().sender == self.sharesContract, "Forbidden");
        self.reply(
            Supply{
                subject: self.subject,
                supply: self.supply,
                holder: msg.holder,
                amount: msg.amount,
                incr: msg.incr,
                value: msg.value
            }.toCell()
        );
    }

    inline fun calculate_sharesWallet_init(owner: Address): StateInit {
        return initOf SharesWallet(owner, self.subject, myAddress());
    }

}

