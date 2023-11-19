import "@stdlib/deploy";

import "./SharesWallet";
import "./SharesKey";

message UpdateFeeDestination {
    feeDestination: Address;
}

message UpdateAdmin {
    newAdmin: Address;
}

message UpdateFeePercentages {
    protocolFeePercentage: Int as uint16;
    subjectFeePercentage: Int as uint16;
}

message NewKey {
    subject: Address;
    initialSupply: Int as uint16;
}

message Trade {
    subject: Address;
    holder: Address;
    amount: Int as uint16;
    increment: Bool;
}

contract Shares with Deployable {

    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");
    const divFactor: Int = 10000000;

    admin: Address;
    feeDestination: Address;
    protocolFeePercentage: Int as uint8 = 5;
    subjectFeePercentage: Int as uint8 = 5;
    totalSupply: Int as uint32 = 0;

    key_content: Cell;

    init(key_content: Cell) {
        self.admin = sender();
        self.feeDestination = sender();
        self.key_content = key_content;
    }

    receive() {}

    receive(msg: UpdateAdmin) {
        require(self.admin == sender(), "Invalid sender");
        self.admin = msg.newAdmin;
    }

    receive(msg: UpdateFeeDestination) {
        require(self.admin == sender(), "Invalid sender");
        self.feeDestination = msg.feeDestination;
    }

    receive(msg: UpdateFeePercentages) {
        require(self.admin == sender(), "Invalid sender");
        self.protocolFeePercentage = msg.protocolFeePercentage;
        self.subjectFeePercentage = msg.subjectFeePercentage;
    }

    // Initialize the subject

    receive(msg: NewKey) {
        let ctx: Context = context();
        let initCodeKey: StateInit = self.calculate_sharesKey_init(msg.subject);
        let price: Int = self.getPrice(0, msg.initialSupply);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        let remain: Int = self.estimate_rest_value(ctx.value);
        require(remain >= price + protocolFee + subjectFee, "Insufficient funds");
        send(SendParameters{
            to: contractAddress(initCodeKey),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: FirstKeys{
                subject: ctx.sender,
                remain: remain,
                initialSupply: msg.initialSupply
            }.toCell(),
            code: initCodeKey.code,
            data: initCodeKey.data
        });
    }

    bounced(src: bounced<FirstKeys>) {
        // the message reverted, so we refund the sender
        // TODO For some reason the compiler says:
        // Type bounced<"FirstKeys"> does not have a field named "subject"
        // self.send_funds(src.subject, src.remain);
    }

    receive(msg: AfterNewKey) {
        let ctx: Context = context();
        let initCodeKey: StateInit = self.calculate_sharesKey_init(msg.subject);
        require(ctx.sender == contractAddress(initCodeKey), "Invalid sender");
        let price: Int = self.getPrice(0, msg.supply);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        self.send_funds(self.feeDestination, protocolFee);
        self.send_funds(msg.subject, subjectFee);
    }

    inline fun send_funds(address: Address, amount: Int) {
        send(SendParameters{
            to: address,
            value: amount,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors
        });
    }

    // buy/sell shares

    receive(msg: Trade) {
        let ctx: Context = context();
        let initCodeKey: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCodeWallet: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCodeKey));
        require(ctx.sender == msg.holder, "Invalid sender");
        let remain: Int = self.estimate_rest_value(ctx.value);
        send(SendParameters{
            to: contractAddress(initCodeWallet),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: CurrentSupply{
                holder: msg.holder,
                amount: msg.amount,
                increment: msg.increment,
                remain: ctx.value
            }.toCell()
        });
    }

    receive(msg: CompleteTrade) {
        let ctx: Context = context();
        let initCodeKey: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCodeWallet: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCodeKey));
        require(ctx.sender == contractAddress(initCodeKey), "Invalid sender");
        let price: Int = self.getPrice(msg.supply, msg.amount);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        if (msg.remain < price + protocolFee + subjectFee) {
            self.send_funds(msg.holder, msg.remain);
        } else if (!msg.increment && (msg.amount > msg.balance || msg.amount >= msg.supply)) {
            self.send_funds(msg.holder, msg.remain);
        } else {
            send(SendParameters{
                to: contractAddress(initCodeKey),
                value: 0,
                bounce: true,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: UpdateSupplyAndBalance{
                    subject: msg.subject,
                    holder: msg.holder,
                    amount: msg.amount,
                    increment: msg.increment,
                    price: price,
                    protocolFee: protocolFee,
                    subjectFee: subjectFee
                }.toCell()
            });
        }
    }

    bounced(src: bounced<UpdateSupplyAndBalance>) {
        // the message reverted, so we refund the sender
        // TODO Same error as above
        // self.send_funds(src.holder, src.remain);
    }

    receive(msg: UpdateSupplyAndBalance) {
        let initCodeKey: StateInit = self.calculate_sharesKey_init(msg.subject);
        require(sender() == contractAddress(initCodeKey), "Invalid sender");
        self.send_funds(self.feeDestination, msg.protocolFee);
        self.send_funds(msg.subject, msg.subjectFee);
        self.send_funds(msg.holder, msg.price - msg.protocolFee - msg.subjectFee);
    }

    inline fun estimate_rest_value(remain: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - remain;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        return remain - (storageFee + self.gasConsumption);
    }

    inline fun calculate_sharesKey_init(subject: Address): StateInit {
        return initOf SharesKey(subject, myAddress());
    }

    inline fun calculate_sharesWallet_init(holder: Address, subject: Address, keyAddress: Address): StateInit {
        return initOf SharesWallet(holder, subject, keyAddress);
    }

    get fun getVersion(): String {
        return "1.0.0";
    }

    get fun getFeeDestination(): Address {
        return self.feeDestination;
    }

    get fun getFeePercentage(): Int {
        return self.protocolFeePercentage;
    }

    get fun getSubjectFeePercentage(): Int {
        return self.subjectFeePercentage;
    }

    get fun getPrice(supply: Int, amount: Int): Int {
        let sum1: Int = 0;
        if (supply != 0) {
            sum1 = ((supply - 1) * (supply) * (2 * (supply - 1) + 1)) / 6;
        }
        let sum2: Int = 0;
        if (supply != 0 || amount != 1) {
            sum2 = ((supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1)) / 6;
        }
        // TODO Set the correct factor
        return (sum1 + sum2) * self.divFactor;
    }


    get fun getBuyPrice(sharesSubject: Address, supply: Int, amount: Int): Int {
        return self.getPrice(supply, amount);
    }

    get fun getSellPrice(sharesSubject: Address, supply: Int, amount: Int): Int {
        return self.getPrice(supply - amount, amount);
    }
    get fun getBuyPriceAfterFee(sharesSubject: Address, supply: Int, amount: Int): Int {
        let price: Int = self.getBuyPrice(sharesSubject, supply, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / self.divFactor;
        let subjectFee: Int = price * self.subjectFeePercentage / self.divFactor;
        return price + protocolFee + subjectFee;
    }

    get fun getSellPriceAfterFee(sharesSubject: Address, supply: Int, amount: Int): Int {
        let price: Int = self.getSellPrice(sharesSubject, supply, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / self.divFactor;
        let subjectFee: Int = price * self.subjectFeePercentage / self.divFactor;
        return price - protocolFee - subjectFee;
    }

}

