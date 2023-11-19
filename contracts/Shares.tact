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

message BuySellShares {
    subject: Address;
    holder: Address;
    amount: Int as uint16;
    incr: Bool;
}

contract Shares with Deployable {

    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

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

    receive(msg: NewKey) {
        let ctx: Context = context();
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        let price: Int = self.getPrice(0, initialSupply);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: FirstKeys{
                sender: ctx.sender,
                value: _estimate_rest_value(ctx.value),
                owner: msg.subject,
                initialSupply: msg.initialSupply,
                price: price,
                protocolFee: protocolFee,
                subjectFee: subjectFee,
            }.toCell(),
            code: initCode.code,
            data: initCode.data
        });
    }

    receive(msg: BuySellShares) {
        let ctx: Context = context();
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCode2: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCode));
        require(ctx.sender == msg.holder, "Invalid sender");
        send(SendParameters{
            to: contractAddress(initCode2),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: CurrentSupply{
                holder: msg.holder,
                amount: msg.amount,
                incr: msg.incr,
                value: ctx.value
            }.toCell()
        });
    }

    receive(msg: Supply) {
        let ctx: Context = context();
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCode2: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCode));
        require(ctx.sender == contractAddress(initCode), "Invalid sender");
        let subject: Address = msg.subject;
        let holder: Address = msg.holder;
        let supply: Int = msg.supply;
        let amount: Int = msg.amount;
        let price: Int = self.getPrice(supply, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        let remain: Int = self._estimate_rest_value(msg.value);
        // it should refund the user
        require(remain >= price + protocolFee + subjectFee, "Insufficient funds");
        if (!msg.incr) {
            require(supply > msg.amount, "Insufficient keys");
        }
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: UpdateSupplyAndBalance{
                holder: msg.holder,
                amount: msg.amount,
                incr: msg.incr,
                value: msg.value,
                price: price,
                protocolFee: protocolFee,
                subjectFee: subjectFee
            }.toCell()
        });
    }

    receive(msg: UpdatedSupplyAndBalance) {

        send(SendParameters{
            to: self.feeDestination,
            value: protocolFee,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors
        });

    }

    receive(msg: RevertError) {
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        require(ctx.sender == contractAddress(initCode), "Invalid sender");
        _refund_holder(_estimate_rest_value(msg.value));
    }

   inline fun _refund_holder(remain: Int): Int {
        send(SendParameters{
            to: msg.holder,
            value: remain,
            bounce: true,
            mode: SendIgnoreErrors
        });
    }

    inline fun _estimate_rest_value(remain: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - remain;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        return remain - (storageFee + self.gasConsumption);
    }

    inline fun calculate_sharesKey_init(subject: Address): StateInit {
        return initOf SharesKey(subject, myAddress());
    }

    inline fun calculate_sharesWallet_init(owner: Address, subject: Address, keyAddress: Address): StateInit {
        return initOf SharesWallet(owner, subject, keyAddress);
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
        return (sum1 + sum2) * 10000000;
    }


    get fun getBuyPrice(sharesSubject: Address, supply: Int, amount: Int): Int {
        return self.getPrice(supply, amount);
    }

    get fun getSellPrice(sharesSubject: Address, supply: Int, amount: Int): Int {
        return self.getPrice(supply - amount, amount);
    }
    get fun getBuyPriceAfterFee(sharesSubject: Address, supply: Int, amount: Int): Int {
        let price: Int = self.getBuyPrice(sharesSubject, supply, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        return price + protocolFee + subjectFee;
    }

    get fun getSellPriceAfterFee(sharesSubject: Address, supply: Int, amount: Int): Int {
        let price: Int = self.getSellPrice(sharesSubject, supply, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        return price - protocolFee - subjectFee;
    }

}

