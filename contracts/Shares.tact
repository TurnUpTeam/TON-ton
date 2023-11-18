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

    inline fun calculate_sharesKey_init(owner_address: Address): StateInit {
        return initOf SharesKey(owner_address, myAddress());
    }

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

    receive() {}

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

/*
    get fun getBuyPrice(sharesSubject: Address, amount: Int): Int {
        let supply: Int = 0;
        if (self.sharesSupply.get(sharesSubject) != null) {
            supply = (self.sharesSupply.get(sharesSubject))!!;
        }
        return self.getPrice(supply, amount);
    }

    get fun getSellPrice(sharesSubject: Address, amount: Int): Int {
        let supply: Int = 0;
        if (self.sharesSupply.get(sharesSubject) != null) {
            supply = (self.sharesSupply.get(sharesSubject))!!;
        }
        return self.getPrice(supply - amount, amount);
    }
    get fun getBuyPriceAfterFee(sharesSubject: Address, amount: Int): Int {
        let price: Int = self.getBuyPrice(sharesSubject, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        return price + protocolFee + subjectFee;
    }

    get fun getSellPriceAfterFee(sharesSubject: Address, amount: Int): Int {
        let price: Int = self.getSellPrice(sharesSubject, amount);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        return price - protocolFee - subjectFee;
    }

    get fun getBalance(sharesSubject: Address, user: Address): Int {
        let sharesBalance: Balance = self.sharesBalance.get(sharesSubject)!!;
        if (sharesBalance.balance.get(user) != null) {
            return sharesBalance.balance.get(user)!!;
        }
        return 0;
    }
*/

}

