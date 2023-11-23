import '@ton-community/test-utils';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton-community/sandbox';
import { Address, beginCell, toNano } from 'ton-core';

import { Shares, NewKey } from '../wrappers/Shares';
import { SharesKey } from '../wrappers/SharesKey';
import { SharesWallet } from '../wrappers/SharesWallet';

const sleep = require('sleep');

describe('Integration', () => {
    let blockchain: Blockchain;

    let newKeyMsg: NewKey;
    // contracts
    let wallet: SandboxContract<SharesWallet>;
    let key: SandboxContract<SharesKey>;
    let shares: SandboxContract<Shares>;

    // addresses
    let deployer: SandboxContract<TreasuryContract>;
    let subject: SandboxContract<TreasuryContract>;
    let subject2: SandboxContract<TreasuryContract>;
    let holder: SandboxContract<TreasuryContract>;
    let holder2: SandboxContract<TreasuryContract>;
    let holder3: SandboxContract<TreasuryContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        shares = blockchain.openContract(await Shares.fromInit());

        deployer = await blockchain.treasury('deployer');

        let deployResult = await shares.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: shares.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and shares are ready to use
    });

    it("should expect the right parameters", async()=>{
        expect(await shares.getGetFeeDestination()).toEqualAddress(deployer.address);
        expect(await shares.getGetFeePercentage()).toEqual(5n);
        expect(await shares.getGetSubjectFeePercentage()).toEqual(5n);

    });

    it("should create a first key and the relative holder", async()=>{

        const price = await shares.getGetPrice(0n, 3n);
        const protocolFeePercentage = await shares.getGetFeePercentage();
        const subjectFeePercentage = await shares.getGetSubjectFeePercentage();

        const gasConsumption = await shares.getGetGasConsumption();

        // @ts-ignore
        let protocolFee = price * protocolFeePercentage / 100n;
        // @ts-ignore
        let subjectFee = price * subjectFeePercentage / 100n;

        subject = await blockchain.treasury('subject');
        newKeyMsg = {
            $$type: 'NewKey',
            subject: subject.address,
            initialSupply: 3n,
        };

        const result = await shares.send(
            subject.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            newKeyMsg
        );

        expect(result.transactions).toHaveTransaction({
            from: subject.address,
            to: shares.address,
            success: true
        })

        const keyAddress = await shares.getGetKeyAddress(subject.address);
        expect(result.transactions).toHaveTransaction({
            from: shares.address,
            to: keyAddress,
            success: true
        })

        // key supply

        const keyContract = blockchain.openContract(await SharesKey.fromAddress(keyAddress));
        const keySupply = await keyContract.getSupply();
        expect(keySupply).toEqual(3n);

        // wallet balance
        const walletAddress = await shares.getGetWalletAddress(subject.address, subject.address);
        expect(result.transactions).toHaveTransaction({
            from: shares.address,
            to: walletAddress,
            success: true
        })

        const walletContract = blockchain.openContract(await SharesWallet.fromAddress(walletAddress));

        const walletBalance = await walletContract.getBalance();
        expect(walletBalance).toEqual(3n);

    })

});
