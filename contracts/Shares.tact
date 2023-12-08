import "@stdlib/deploy";

import "./SharesWallet";
import "./SharesKey";

message UpdateAdmin {
    newAdmin: Address;
}

message UpdateFeeDestination {
    feeDestination: Address;
}

message UpdateFeePercentages {
    protocolFeePercentage: Int as uint16;
    subjectFeePercentage: Int as uint16;
}

message NewKey {
    subject: Address;
    initialSupply: Int as uint16;
}

message TradeKey {
    subject: Address;
    supply: Int as uint16;
    holder: Address;
    balance: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
}

// Event emitted at the end of the execution
message Trade {
    success: Bool;
    supply: Int as uint16;
    subject: Address;
    holder: Address;
    balance: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
}

struct Query {
    supply: Int as uint16;
    subject: Address;
    holder: Address;
    balance: Int as uint16;
    amount: Int as uint16;
    value: Int as coins;
    increment: Bool;
}

contract Shares with Deployable {

    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.3");
    const divFactor: Int = 10000000;

    admin: Address;
    feeDestination: Address;
    protocolFeePercentage: Int as uint8 = 5;
    subjectFeePercentage: Int as uint8 = 5;
    totalSupply: Int as uint32 = 0;

    lastQueryId: Int as uint64 = 0;
    queries: map<Int, Query>;

    init() {
        self.admin = sender();
        self.feeDestination = sender();
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


    // first key

    receive(msg: NewKey) {
        require(msg.initialSupply > 0, "Initial supply must be greater than 0");
        let ctx: Context = context();
        require(ctx.sender == msg.subject, "Invalid sender");
        let initCodeKey: StateInit = self.calculateSharesKeyInit(msg.subject);
        let price: Int = self.getPrice(0, msg.initialSupply);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        require(ctx.value >= price + protocolFee + subjectFee + self.gasConsumption, "Insufficient funds");
        self.lastQueryId = self.lastQueryId + 1;
        self.queries.set(self.lastQueryId, Query{
            supply: 0,
            subject: msg.subject,
            holder: msg.subject,
            balance: 0,
            amount: msg.initialSupply,
            value: ctx.value,
            increment: true
        });
        send(SendParameters{
            to: contractAddress(initCodeKey),
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: UpdateSupply{
                queryId: self.lastQueryId,
                amount: msg.initialSupply,
                supply: 0,
                increment: true
            }.toCell(),
            code: initCodeKey.code,
            data: initCodeKey.data
        });
    }

    bounced(src: UpdateSupply) {
        self.sendValueBackToUser(src.queryId);
        self.emitFinalEvent(src.queryId, false);
    }

    inline fun emitFinalEvent(queryId: Int, success: Bool) {
        let subject: Address = newAddress(0, 0);
        let holder: Address = newAddress(0, 0);
        let supply: Int = 0;
        let balance: Int = 0;
        let amount: Int = 0;
        let increment: Bool = false;
        if (self.queries.get(queryId) != null) {
            subject = (self.queries.get(queryId)!!).subject;
            holder = (self.queries.get(queryId)!!).holder;
            balance = (self.queries.get(queryId)!!).balance;
            supply = (self.queries.get(queryId)!!).supply;
            amount = (self.queries.get(queryId)!!).amount;
            increment = (self.queries.get(queryId)!!).increment;
        }
        emit(Trade{
            success: success,
            supply: supply,
            subject: subject,
            holder: holder,
            balance: balance,
            amount: amount,
            increment: increment
        }.toCell());
        self.queries.set(queryId, null);
    }

    receive(msg: SupplyUpdated) {
        let ctx: Context = context();
        let subject: Address = newAddress(0, 0);
        let holder: Address = newAddress(0, 0);
        let supply: Int = 0;
        let balance: Int = 0;
        let amount: Int = 0;
        let increment: Bool = false;
        if (self.queries.get(msg.queryId) != null) {
            subject = (self.queries.get(msg.queryId)!!).subject;
            holder = (self.queries.get(msg.queryId)!!).holder;
            balance = (self.queries.get(msg.queryId)!!).balance;
            supply = (self.queries.get(msg.queryId)!!).supply;
            amount = (self.queries.get(msg.queryId)!!).amount;
            increment = (self.queries.get(msg.queryId)!!).increment;
        }
        let initCodeKey: StateInit = self.calculateSharesKeyInit(subject);
        require(ctx.sender == contractAddress(initCodeKey), "Invalid sender");
        let initCodeWallet: StateInit = self.calculateSharesWalletInit(holder, subject);
        send(SendParameters{
            to: contractAddress(initCodeWallet),
            value: 0,
            bounce: true,
            body: UpdateBalance{
                queryId: msg.queryId,
                amount: amount,
                holder: holder,
                balance: balance,
                increment: increment
            }.toCell(),
            mode: SendRemainingValue,
            code: initCodeWallet.code,
            data: initCodeWallet.data
        });
    }

    bounced(src: bounced<UpdateBalance>) {
    // TODO we have to revert the previous change in the supply
        let subject: Address = newAddress(0, 0);
        let amount: Int = 0;
        let supply: Int = 0;
        let increment: Bool = false;
        if (self.queries.get(src.queryId) != null) {
            amount = (self.queries.get(src.queryId)!!).amount;
            subject = (self.queries.get(src.queryId)!!).subject;
            supply = (self.queries.get(src.queryId)!!).supply;
            increment = (self.queries.get(src.queryId)!!).increment;
        }
        let initCodeKey: StateInit = self.calculateSharesKeyInit(subject);
        send(SendParameters{
            to: contractAddress(initCodeKey),
            // we send the gas needed to revert the previous change in the supply
            value: ton("0.09"),
            bounce: true,
            body: FixSupply{
                queryId: src.queryId,
                amount: amount,
                supply: supply,
                increment: increment
            }.toCell()
        });
    }

    // bounced(src: FixSupply) {}

    receive(msg: SupplyFixed) {
        self.sendValueBackToUser(msg.queryId);
        self.emitFinalEvent(msg.queryId, false);
    }

    receive(msg: BalanceUpdated) {
        let supply: Int = 0;
        let amount: Int = 0;
        let subject: Address = newAddress(0, 0);
        let holder: Address = newAddress(0, 0);
        let increment: Bool = false;
        if (self.queries.get(msg.queryId) != null) {
            supply = (self.queries.get(msg.queryId)!!).supply;
            subject = (self.queries.get(msg.queryId)!!).subject;
            holder  = (self.queries.get(msg.queryId)!!).holder;
            amount = (self.queries.get(msg.queryId)!!).amount;
            increment = (self.queries.get(msg.queryId)!!).increment;
        } else {
            require(false, "Query not found");
        }
        let price: Int = 0;
        if (increment) {
            price = self.getPrice(supply, amount);
        } else {
            price = self.getPrice(supply - amount, amount);
        }
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        if (increment) {
            self.send_funds(self.feeDestination, protocolFee);
            self.send_funds(subject, subjectFee);
        } else {
            self.send_funds(holder, price - protocolFee - subjectFee);
            self.send_funds(self.feeDestination, protocolFee);
            self.send_funds(subject, subjectFee);
        }
        self.emitFinalEvent(msg.queryId, true);
    }


    // trading

    receive(msg: TradeKey) {
        let ctx: Context = context();
        let initCodeKey: StateInit = self.calculateSharesKeyInit(msg.subject);
        require(ctx.sender == msg.holder, "Invalid sender");
        if (msg.supply == 0) {
            // first key
            require(msg.holder == msg.subject, "Not the subject");
        }
        let price: Int = 0;
        if (msg.increment) {
            price = self.getPrice(msg.supply, msg.amount);
        } else {
            price = self.getPrice(msg.supply - msg.amount, msg.amount);
        }
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        if (msg.increment) {
            require(ctx.value >= price + protocolFee + subjectFee + self.gasConsumption, "Insufficient funds");
        } else {
            require(ctx.value >= self.gasConsumption, "Insufficient funds");
            // selling shares
            if (msg.holder == msg.subject) {
                require(msg.amount < msg.supply, "Subject cannot sell last key");
            } else {
                require(msg.amount <= msg.balance, "Insufficient balance");
            }
        }

        self.lastQueryId = self.lastQueryId + 1;
        self.queries.set(self.lastQueryId, Query{
            supply: msg.supply,
            subject: msg.subject,
            holder: msg.holder,
            balance: msg.balance,
            amount: msg.amount,
            value: ctx.value,
            increment: msg.increment
        });

        send(SendParameters{
            to: contractAddress(initCodeKey),
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: UpdateSupply{
                queryId: self.lastQueryId,
                supply: msg.supply,
                amount: msg.amount,
                increment: msg.increment
            }.toCell()
        });
            }


    inline fun sendValueBackToUser(queryId: Int) {
        let value: Int = 0;
        let holder: Address = newAddress(0, 0);
        if (self.queries.get(queryId) != null) {
            value = (self.queries.get(queryId)!!).value;
            holder = (self.queries.get(queryId)!!).holder;
        }
        if (value > 0) {
            // TODO This should be improved keeping only the used gas
            self.send_funds(holder, value - self.gasConsumption);
        }
    }

    inline fun send_funds(address: Address, amount: Int) {
        send(SendParameters{
            to: address,
            value: amount,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors
        });
    }

    inline fun calculateSharesKeyInit(subject: Address): StateInit {
        return initOf SharesKey(subject, myAddress());
    }

    get fun getKeyAddress(subject: Address): Address {
        return contractAddress(self.calculateSharesKeyInit(subject));
    }

    inline fun calculateSharesWalletInit(holder: Address, subject: Address): StateInit {
        return initOf SharesWallet(holder, subject, myAddress());
    }

    get fun getWalletAddress(holder: Address, subject: Address): Address {
        return contractAddress(self.calculateSharesWalletInit(holder, subject));
    }

    get fun getVersion(): String {
        return "1.0.0";
    }

    get fun getGasConsumption(): Int {
        return self.gasConsumption;
    }

    get fun getLastQueryId(): Int {
        return self.lastQueryId;
    }

    get fun getQueryExist(queryId: Int): Bool {
    return (self.queries.get(queryId) != null);
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

