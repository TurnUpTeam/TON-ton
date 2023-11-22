import "@stdlib/deploy";

import "./SharesWallet";

message FirstKeys {
    subject: Address;
    remain: Int as coins;
    initialSupply: Int as uint16;
}

message AfterNewKey {
    subject: Address;
    supply: Int as uint16;
}

message CurrentSupply {
    holder: Address;
    amount: Int as uint16;
    increment: Bool;
    remain: Int as coins;
}

message CompleteTrade{
    subject: Address;
    holder: Address;
    supply: Int as uint16;
    balance: Int as uint16;
    amount: Int as uint16;
    increment: Bool;
    remain: Int as coins;
}

contract SharesKey with Deployable {
    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    subject: Address;
    sharesContract: Address; // Shares contract
    supply: Int as uint16 = 0;

    init(subject: Address, sharesContract: Address) {
        dump("SharesKey init");
        dump(sender() == sharesContract);
        require(sender() == sharesContract, "Not the shares contract");
        self.subject = subject;
        self.sharesContract = sender();
    }

    receive() {}

    receive(msg: FirstKeys) {
        dump("FirstKeys");
        /*
        require(sender() == self.sharesContract, "Forbidden");
        require(self.supply == 0, "Already initialized");
        dump("FirstKeys");
        let initCode: StateInit = self.calculate_sharesWallet_init(self.subject);
        self.supply = msg.initialSupply;
        // this should never fail
        dump("Deploying wallet");
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            body: UpdateBalance{
                    amount: msg.initialSupply,
                    increment: true
                }.toCell(),
            mode: SendRemainingValue + SendIgnoreErrors,
            code: initCode.code,
            data: initCode.data
        });
        send(SendParameters{
            to: self.sharesContract,
            value: 0,
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: AfterNewKey{
                subject: self.subject,
                supply: self.supply
            }.toCell()
        });
        */
    }

    /*virtual inline fun _internal_transfer_excesses(ctx: Context, msg: JettonInternalTransfer, remain: Int){
        if((msg.response_address != newAddress(0, 0)) && remain > 0){
            send(SendParameters{
                to: msg.response_address,
                value: remain,
                bounce: false,
                mode: SendIgnoreErrors,
                body: JettonExcesses{
                    query_id: msg.query_id
                }.toCell()
            });
        }
    }*/

    bounced(src: UpdateBalance) {
        if (src.increment) {
            self.supply = self.supply - src.amount;
        } else {
            self.supply = self.supply + src.amount;
        }
    }

    // get supply

    receive(msg: CurrentSupply) {
        require(self.supply > 0, "Not initialized");
        require(sender() == self.sharesContract, "Forbidden");
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: GetBalance{
                holder: msg.holder,
                amount: msg.amount,
                increment: msg.increment,
                remain: msg.remain,
                balance: 0
            }.toCell()
        });
    }

    receive(msg: GetBalance) {
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        require(sender() == contractAddress(initCode), "Forbidden");
        send(SendParameters{
            to: self.sharesContract,
            value: 0,
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: CompleteTrade{
                    subject: self.subject,
                    holder: msg.holder,
                    supply: self.supply,
                    amount: msg.amount,
                    balance: msg.balance,
                    increment: msg.increment,
                    remain: msg.remain
                }.toCell()
        });
    }

    receive(msg: UpdateSupplyAndBalance) {
        require(context().sender == self.sharesContract, "Forbidden");
        if (msg.increment) {
            self.supply = self.supply + msg.amount;
        } else {
            if (msg.holder == self.subject) {
                require(self.supply > msg.amount, "Subject cannot sell last key");
            }
            self.supply = self.supply - msg.amount;
        }
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        send(SendParameters{
         to: contractAddress(initCode),
         value: 0,
         bounce: true,
         mode: SendRemainingValue + SendIgnoreErrors,
         body: UpdateSupplyAndBalance{
            subject: self.subject,
           holder: msg.holder,
           amount: msg.amount,
           increment: msg.increment,
           balance: msg.balance,
           price: msg.price,
           protocolFee: msg.protocolFee,
           subjectFee: msg.subjectFee
         }.toCell()
        });
    }

    receive(msg: WalletUpdated) {
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        require(sender() == contractAddress(initCode), "Forbidden");
        send(SendParameters{
                    to: self.sharesContract,
                    value: 0,
                    bounce: false,
                    mode: SendRemainingValue + SendIgnoreErrors,
                       body: UpdateSupplyAndBalance{
                           subject: self.subject,
                           holder: msg.holder,
                           amount: msg.amount,
                           balance: msg.balance,
                           increment: msg.increment,
                           price: msg.price,
                           protocolFee: msg.protocolFee,
                           subjectFee: msg.subjectFee
                       }.toCell()
                });

    }

    get fun supply(): Int {
        return self.supply;
    }

    inline fun calculate_sharesWallet_init(holder: Address): StateInit {
        return initOf SharesWallet(holder, self.subject, myAddress());
    }

}

