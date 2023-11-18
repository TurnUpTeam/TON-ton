import "@stdlib/deploy";

import "./SharesWallet";
import "./SharesKey";

const ONE_ETHER: Int = 1000000000000000000;
const DIV_FACTOR: Int = 2000;

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

message BuyShares {
    subject: Address;
    holder: Address;
    amount: Int as uint16;
}

contract Shares with Deployable {
    admin: Address;
    feeDestination: Address;
    protocolFeePercentage: Int as uint16 = 0;
    subjectFeePercentage: Int as uint16 = 0;
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
        require(msg.subject == ctx.sender, "Invalid sender");
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: FirstKeys{
                owner: msg.subject,
                initialSupply: msg.initialSupply
            }.toCell(),
            code: initCode.code,
            data: initCode.data
        });
    }

    receive(msg: BuyShares) {
        let ctx: Context = context();
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCode2: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCode));
        require(ctx.sender == msg.holder, "Invalid sender");
        send(SendParameters{
            to: contractAddress(initCode2),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: Holder{
                holder: msg.holder,
                amount: msg.amount
            }.toCell()
        });
    }

    receive(msg: SupplyAndBalance) {
        let ctx: Context = context();
        let initCode: StateInit = self.calculate_sharesKey_init(msg.subject);
        let initCode2: StateInit = self.calculate_sharesWallet_init(msg.holder, msg.subject, contractAddress(initCode));
        require(ctx.sender == contractAddress(initCode), "Invalid sender");
        let subject: Address = msg.subject;
        let holder: Address = msg.holder;
        let supply: Int = msg.supply;
        let balance: Int = msg.balance;
        let price: Int = self.getPrice(supply, balance);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        // we have to add the gas to the following
        require(ctx.value >= price + protocolFee + subjectFee, "Insufficient funds");
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: UpdateHolderBalance{
                holder: msg.holder,
                amount: msg.amount,
                incr: true
            }.toCell()
        });
        // TODO send the money

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
        return (sum1 + sum2) * ONE_ETHER / DIV_FACTOR;
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

