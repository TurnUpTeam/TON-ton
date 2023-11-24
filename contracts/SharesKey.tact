import "@stdlib/deploy";

import "./SharesWallet";

/*
message SetInitialSupply {
    queryId: Int as uint64;
    supply: Int as uint16;
}
*/

message UpdateSupply {
    queryId: Int as uint64;
    supply: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
}

message SupplyUpdated {
    queryId: Int as uint64;
}

message FixSupply {
    queryId: Int as uint64;
    supply: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
}

message SupplyFixed {
    queryId: Int as uint64;
    supply: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
}

contract SharesKey with Deployable {

    // TODO tune the following constants
    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    subject: Address;
    sharesContract: Address;
    supply: Int as uint16 = 0;

    init(subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the shares contract");
        self.subject = subject;
        self.sharesContract = sender();
    }

    receive(msg: UpdateSupply) {
        // dump("Receiving UpdateSupply");
        // dump(msg.supply);
        // dump(self.supply);
        require(context().sender == self.sharesContract, "Forbidden");
        require(msg.supply == self.supply, "Supply mismatch");
        if (msg.increment) {
            self.supply = self.supply + msg.amount;
        } else {
            require(msg.amount < self.supply, "Cannot sell last key");
            self.supply = self.supply - msg.amount;
        }
        let remain: Int = self.estimateRestValue() - context().readForwardFee();
        // dump("New supply");
        // dump(self.supply);
        // dump(remain);
        send(SendParameters{
            to: self.sharesContract,
            value: remain,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SupplyUpdated{
                queryId: msg.queryId
            }.toCell()
        });
        // dump("Sent");
    }

    receive(msg: FixSupply) {
        require(context().sender == self.sharesContract, "Forbidden");
        if (!msg.increment) {
            self.supply = self.supply + msg.amount;
        } else {
            self.supply = self.supply - msg.amount;
        }
        send(SendParameters{
            to: self.sharesContract,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SupplyFixed{
                queryId: msg.queryId,
                amount: msg.amount,
                supply: msg.supply,
                increment: msg.increment
            }.toCell()
        });
    }

    inline fun estimateRestValue(): Int {
        let balance: Int = myBalance();
        let storageFee: Int = self.minTonsForStorage - min(balance, self.minTonsForStorage);
        return balance - (storageFee + self.gasConsumption);
    }

    get fun supply(): Int {
        return self.supply;
    }

    inline fun calculateSharesWalletInit(holder: Address): StateInit {
        return initOf SharesWallet(holder, self.subject, myAddress());
    }

}

