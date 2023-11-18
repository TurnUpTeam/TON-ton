import "@stdlib/deploy";

import "./SharesWallet";

message FirstKeys {
    owner: Address;
    initialSupply: Int as uint16;
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

    inline fun calculate_sharesWallet_init(owner: Address): StateInit {
        return initOf SharesWallet(owner, self.subject, myAddress());
    }

}

