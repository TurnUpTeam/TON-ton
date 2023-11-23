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

struct Query {
    givenSupply: Int as uint16;
    subject: Address;
    holder: Address;
    amount: Int as uint16;
    value: Int as coins;
    increment: Bool;
}

contract Shares with Deployable {

    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.2");
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
        dump("NewKey");
        require(msg.initialSupply > 0, "Initial supply must be greater than 0");
        let ctx: Context = context();
        require(ctx.sender == msg.subject, "Invalid sender");
        dump(ctx.value);
        let initCodeKey: StateInit = self.calculateSharesKeyInit(msg.subject);
        let price: Int = self.getPrice(0, msg.initialSupply);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        require(ctx.value >= price + protocolFee + subjectFee + self.gasConsumption, "Insufficient funds");
        self.lastQueryId = self.lastQueryId + 1;
        self.queries.set(self.lastQueryId, Query{
            givenSupply: 0,
            subject: msg.subject,
            holder: msg.subject,
            amount: msg.initialSupply,
            value: ctx.value,
            increment: false
        });
        send(SendParameters{
            to: contractAddress(initCodeKey),
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: FirstKeys{
                queryId: self.lastQueryId,
                supply: msg.initialSupply
            }.toCell(),
            code: initCodeKey.code,
            data: initCodeKey.data
        });
    }

    bounced(src: FirstKeys) {
        // the message reverted, so we refund the sender
        // TODO For some reason the compiler says:
        // Type bounced<"FirstKeys"> does not have a field named "subject"
        dump(src.queryId);
        // self.send_funds(src.subject, src.remain);
    }

    receive(msg: FirstKeys) {
        dump("Shares:FirstKeys");
        let ctx: Context = context();
        dump(ctx.value);
        let subject: Address = newAddress(0, 0);
        dump("What the fuck");
        if (self.queries.get(msg.queryId) != null) {
            subject = (self.queries.get(msg.queryId)!!).subject;
        }
        let initCodeKey: StateInit = self.calculateSharesKeyInit(subject);
        require(ctx.sender == contractAddress(initCodeKey), "Invalid sender");
        let initCodeWallet: StateInit = self.calculateSharesWalletInit(subject, subject);
        send(SendParameters{
            to: contractAddress(initCodeWallet),
            value: 0,
            bounce: true,
            body: UpdateBalance{
                queryId: msg.queryId,
                amount: msg.supply,
                increment: true
            }.toCell(),
            mode: SendRemainingValue,
            code: initCodeWallet.code,
            data: initCodeWallet.data
        });
        dump("Wallet deployed");
    }

    receive(msg: UpdateBalance) {
        dump("Shares:UpdateBalance");
        dump(context().value);
        let givenSupply: Int = 0;
        let subject: Address = newAddress(0, 0);
        dump("What the fuck");
        if (self.queries.get(msg.queryId) != null) {
            dump("Not null");
            givenSupply = (self.queries.get(msg.queryId)!!).givenSupply;
            dump(givenSupply);
            subject = (self.queries.get(msg.queryId)!!).subject;
        } else {
            dump("Query not found");
            require(false, "Query not found");
        }
        let price: Int = self.getPrice(givenSupply, msg.amount);
        dump(price);
        let protocolFee: Int = price * self.protocolFeePercentage / 100;
        let subjectFee: Int = price * self.subjectFeePercentage / 100;
        self.send_funds(self.feeDestination, protocolFee);
        self.send_funds(subject, subjectFee);
        dump("Final balance");
        dump(myBalance());
    }




    // trading

    /*
    receive(msg: TradeKey) {
            let ctx: Context = context();
            let initCodeKey: StateInit = self.calculateSharesKeyInit(msg.subject);
            require(ctx.sender == msg.holder, "Invalid sender");
            if (msg.supply == 0) {
                // first key
                require(msg.holder == msg.subject, "Not the subject");
            }
            let newSupply: Int = msg.supply;
            if (msg.increment) {
            // buying shares
                newSupply = msg.supply + msg.amount;
            } else {
            // selling shares
                if (msg.holder == msg.subject) {
                    require(msg.amount < msg.supply, "Subject cannot sell last key");
                } else {
                    require(msg.amount <= msg.balance, "Insufficient balance");
                }
                newSupply = msg.supply - msg.amount;
            }
            self.lastQueryId = self.lastQueryId + 1;
            self.queries.set(self.lastQueryId, Query{
                supply: msg.supply,
                subject: msg.subject,
                holder: msg.subject,
                amount: msg.supply,
                value: ctx.value,
                increment: msg.increment
            });
            send(SendParameters{
                to: contractAddress(initCodeKey),
                value: 0,
                bounce: true,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: UpdateSupply{
                    queryId: self.lastQueryId,
                    subject: msg.subject,
                    supply: msg.supply,
                    newSupply: newSupply
                }.toCell()
            });
        }
*/

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

