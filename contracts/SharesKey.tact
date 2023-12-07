import "@stdlib/deploy";

import "./SharesWallet";

import "./packages/utils/Estimatable";

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
}

contract SharesKey with Deployable, Estimatable {

    subject: Address;
    sharesContract: Address;
    supply: Int as uint16 = 0;

    init(subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the shares contract");
        self.subject = subject;
        self.sharesContract = sender();
    }

    receive(msg: UpdateSupply) {
        let ctx: Context = context();
        require(context().sender == self.sharesContract, "Forbidden");
        require(msg.supply == self.supply, "Supply mismatch");
        if (msg.increment) {
            self.supply = self.supply + msg.amount;
        } else {
            require(msg.amount < self.supply, "Cannot sell last key");
            self.supply = self.supply - msg.amount;
        }
        let remain: Int = self.estimate_rest_value(ctx) - ctx.readForwardFee();
        send(SendParameters{
            to: self.sharesContract,
            value: remain,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SupplyUpdated{
                queryId: msg.queryId
            }.toCell()
        });
    }

    receive(msg: FixSupply) {
        let ctx: Context = context();
        require(context().sender == self.sharesContract, "Forbidden");
        if (!msg.increment) {
            self.supply = self.supply + msg.amount;
        } else {
            require(msg.amount < self.supply, "Something wrong here");
            self.supply = self.supply - msg.amount;
        }
         let remain: Int = self.estimate_rest_value(ctx) - ctx.readForwardFee();
        send(SendParameters{
            to: self.sharesContract,
            value: remain,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SupplyFixed{
                queryId: msg.queryId
            }.toCell()
        });
    }

    get fun supply(): Int {
        return self.supply;
    }

    inline fun calculateSharesWalletInit(holder: Address): StateInit {
        return initOf SharesWallet(holder, self.subject, myAddress());
    }

}

