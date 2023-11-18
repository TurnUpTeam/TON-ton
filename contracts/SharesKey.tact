import "@stdlib/deploy";

import "./SharesWallet";

message FirstKeys {
    owner: Address;
    initialSupply: Int as uint16;
}

message Holder {
    holder: Address;
    amount: Int as uint16;
}

message UpdateHolderBalance {
    holder: Address;
    amount: Int as uint16;
    incr: Bool;
}

message SupplyAndBalance{
    subject: Address;
    holder: Address;
    supply: Int as uint16;
    balance: Int as uint16;
    amount: Int as uint16;
}

contract SharesKey with Deployable {
    subject: Address;
    sharesContract: Address; // Shares contract
    supply: Int as uint16 = 0;

    init(subject: Address, sharesContract: Address) {
        require(sender() == sharesContract, "Not the shares contract");
        self.subject = subject;
        self.sharesContract = sender();
    }

    receive() {}

    receive(msg: FirstKeys) {
        require(self.supply == 0, "Already initialized");
        let ctx: Context = context();
        require(ctx.sender == self.sharesContract, "Forbidden");
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.owner);
        self.supply = msg.initialSupply;
        send(SendParameters{
         to: contractAddress(initCode),
         value: 0,
         bounce: true,
         mode: SendRemainingValue + SendIgnoreErrors,
         body: UpdateBalance{
             amount: msg.initialSupply,
             incr: true
         }.toCell(),
         code: initCode.code,
         data: initCode.data
        });
    }

    receive(msg: UpdateHolderBalance) {
        require(self.supply > 0, "Not initialized");
        require(context().sender == self.sharesContract, "Forbidden");
        if (msg.incr) {
            self.supply = self.supply + msg.amount;
        } else {
            require(self.supply >= msg.amount, "Insufficient balance");
            self.supply = self.supply + msg.amount;
        }
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        send(SendParameters{
         to: contractAddress(initCode),
         value: 0,
         mode: SendRemainingValue + SendIgnoreErrors,
         body: UpdateBalance{
             amount: msg.amount,
             incr: true
         }.toCell()
        });
    }

    receive(msg: Holder) {
        require(self.supply > 0, "Not initialized");
        require(context().sender == self.sharesContract, "Forbidden");
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.holder);
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: GetBalance{
                amount: msg.amount
            }.toCell()
        });
    }

    receive(msg: Balance) {
        require(self.supply > 0, "Not initialized");
        let initCode: StateInit = self.calculate_sharesWallet_init(msg.owner);
        require(context().sender == contractAddress(initCode), "Forbidden");
        send(SendParameters{
            to: self.sharesContract,
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: SupplyAndBalance{
                subject: self.subject,
                holder: msg.owner,
                supply: self.supply,
                balance: msg.balance,
                amount: msg.amount
            }.toCell()
        });
    }

    inline fun calculate_sharesWallet_init(owner: Address): StateInit {
        return initOf SharesWallet(owner, self.subject, myAddress());
    }

}

