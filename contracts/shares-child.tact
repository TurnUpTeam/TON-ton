import "@stdlib/deploy";

const ONE_ETHER: Int = 1000000000000000000;
const DIV_FACTOR: Int = 2000;

message UpdateFeeDestination {
    feeDestination: Address;
}

message UpdateFeePercentages {
    protocolFeePercentage: Int as uint16;
    subjectFeePercentage: Int as uint16;
}

message BuyShares {
    sharesSubject: Address;
    amount: Int as uint32;
}

message SellShares {
    sharesSubject: Address;
    amount: Int as uint32;
}

struct Balance {
    balance: map<Address, Int as uint32>;
}

contract SharesChild with Deployable {
    admin: Address;
    feeDestination: Address;
    protocolFeePercentage: Int as uint16;
    subjectFeePercentage: Int as uint16;

    sharesSupply: map<Address, Int as uint32>;
    sharesBalance: map<Address, Balance>;
    singleBalance: map<Address, Int as uint32>;

    init(admin: Address, feeDestination: Address, protocolFeePercentage: Int, subjectFeePercentage: Int) {
        self.admin = admin;
        self.feeDestination = feeDestination;
        self.protocolFeePercentage = protocolFeePercentage;
        self.subjectFeePercentage = subjectFeePercentage;
    }

    receive(msg: UpdateFeeDestination) {
        let ctx: Context = context();
        require(self.admin == ctx.sender, "Invalid sender");
        self.feeDestination = msg.feeDestination;
    }

    receive(msg: UpdateFeePercentages) {
        let ctx: Context = context();
        require(self.admin == ctx.sender, "Invalid sender");
        self.protocolFeePercentage = msg.protocolFeePercentage;
        self.subjectFeePercentage = msg.subjectFeePercentage;
    }

    receive() {}

    receive(msg: BuyShares) {
        let ctx: Context = context();
        let supply: Int = 0;
        if (self.sharesSupply.get(msg.sharesSubject) != null) {
            supply = (self.sharesSupply.get(msg.sharesSubject))!!;
        }
        require(supply > 0 || msg.sharesSubject == ctx.sender, "Only the keys' owner can buy the first key");
        let price: Int = self.getPrice(supply, msg.amount);
        let protocolFee: Int = price * self.protocolFeePercentage / ONE_ETHER;
        let subjectFee: Int = price * self.subjectFeePercentage / ONE_ETHER;
        let funds: Int = ctx.value;
        require(funds >= price + protocolFee + subjectFee, "Insufficient funds");
        let balance: Int = self.getBalance(msg.sharesSubject, ctx.sender);
        let newBalance: Int = balance + msg.amount;
        // singleBalance.set(ctx.sender, newBalance);

        //self.sharesBalance.set(msg.sharesSubject, Balance{
        //    balance: singleBalance
        //});

        // more code

    }

    /*
    virtual inline fun _send_payment() {
            let seller: Address = self.auctionInfo.beneficiary;
            let winningBidAmount: Int = self.auctionInfo.nftHighestBid;
            send(SendParameters{
                to: seller,
                value: winningBidAmount - ton("0.06"),
                mode: SendPayGasSeparately,
                bounce: false,
                body: "Pay winning bid amount".asComment()
            });
        }
        */

    // getters

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


}

