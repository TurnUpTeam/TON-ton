import '@ton-community/test-utils';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton-community/sandbox';
import { Address, beginCell, toNano } from 'ton-core';

import { Shares, NewKey, TradeKey } from '../wrappers/Shares';
import { SharesKey } from '../wrappers/SharesKey';
import { SharesWallet } from '../wrappers/SharesWallet';

const sleep = require('sleep');

describe('Integration', () => {
    let blockchain: Blockchain;

    let newKeyMsg: NewKey;
    let tradeKeyMsg: TradeKey;

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

    // it('should deploy', async () => {
    //     expect(await shares.getGetFeeDestination()).toEqualAddress(deployer.address);
    //     expect(await shares.getGetFeePercentage()).toEqual(5n);
    //     expect(await shares.getGetSubjectFeePercentage()).toEqual(5n);
    // });

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

    it("should get lastQueryId", async()=>{

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

        const lastQueryId = await shares.getGetLastQueryId();
        expect(lastQueryId).toEqual(1n)
    })


    it("should throw if first key buyer not the subject", async()=>{

        const price = await shares.getGetPrice(0n, 3n);
        const protocolFeePercentage = await shares.getGetFeePercentage();
        const subjectFeePercentage = await shares.getGetSubjectFeePercentage();

        const gasConsumption = await shares.getGetGasConsumption();

        // @ts-ignore
        let protocolFee = price * protocolFeePercentage / 100n;
        // @ts-ignore
        let subjectFee = price * subjectFeePercentage / 100n;

        subject = await blockchain.treasury('subject');
        subject2 = await blockchain.treasury('subject2');
        newKeyMsg = {
            $$type: 'NewKey',
            subject: subject.address,
            initialSupply: 3n,
        };

        const balanceBefore = await subject2.getBalance();

        let result = await shares.send(
            subject2.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            newKeyMsg
        );

        expect(result.transactions).toHaveTransaction({
            from: subject2.address,
            to: shares.address,
            success: false
        })

        const balanceAfter = await subject2.getBalance();
        expect(balanceBefore - balanceAfter).toBeLessThan(100000000n);

    })

    it("should allow holder to buy a key", async()=>{

        let price = await shares.getGetPrice(0n, 3n);
        let protocolFeePercentage = await shares.getGetFeePercentage();
        let subjectFeePercentage = await shares.getGetSubjectFeePercentage();

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

        await shares.send(
            subject.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            newKeyMsg
        );

        holder = await blockchain.treasury('holder');

        // buying 5 keys
        tradeKeyMsg = {
            $$type: 'TradeKey',
            subject: subject.address,
            supply: 3n,
            holder: holder.address,
            balance: 0n,
            amount: 5n,
            increment: true
        };

        price = await shares.getGetPrice(3n, 5n);
        protocolFeePercentage = await shares.getGetFeePercentage();
        subjectFeePercentage = await shares.getGetSubjectFeePercentage();

        // @ts-ignore
        protocolFee = price * protocolFeePercentage / 100n;
        // @ts-ignore
        subjectFee = price * subjectFeePercentage / 100n;

        const result = await shares.send(
            holder.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            tradeKeyMsg
        );

        expect(result.transactions).toHaveTransaction({
            from: holder.address,
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
        expect(keySupply).toEqual(8n);

        // wallet balance
        const walletAddress = await shares.getGetWalletAddress(holder.address, subject.address);
        expect(result.transactions).toHaveTransaction({
            from: shares.address,
            to: walletAddress,
            success: true
        })

        const walletContract = blockchain.openContract(await SharesWallet.fromAddress(walletAddress));

        const walletBalance = await walletContract.getBalance();
        expect(walletBalance).toEqual(5n);

    })

    it.only("should revert if double trade request", async()=>{

        let price = await shares.getGetPrice(0n, 3n);
        let protocolFeePercentage = await shares.getGetFeePercentage();
        let subjectFeePercentage = await shares.getGetSubjectFeePercentage();

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

        await shares.send(
            subject.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            newKeyMsg
        );

        holder = await blockchain.treasury('holder');

        // buying 5 keys
        tradeKeyMsg = {
            $$type: 'TradeKey',
            subject: subject.address,
            supply: 3n,
            holder: holder.address,
            balance: 0n,
            amount: 10n,
            increment: true
        };

        const walletAddress = await shares.getGetWalletAddress(holder.address, subject.address);
        const walletContract = blockchain.openContract(await SharesWallet.fromAddress(walletAddress));

        try {
            await walletContract.getBalance()
        } catch(error) {
            if (error instanceof Error) {
                expect(error.message).toEqual('Trying to run get method on non-active contract');
            }
        }

        price = await shares.getGetPrice(3n, 10n);
        protocolFeePercentage = await shares.getGetFeePercentage();
        subjectFeePercentage = await shares.getGetSubjectFeePercentage();

        // @ts-ignore
        protocolFee = price * protocolFeePercentage / 100n;
        // @ts-ignore
        subjectFee = price * subjectFeePercentage / 100n;

        await shares.send(
            holder.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            tradeKeyMsg
        );

        const keyAddress = await shares.getGetKeyAddress(subject.address);
        const keyContract = blockchain.openContract(await SharesKey.fromAddress(keyAddress));
        let keySupply = await keyContract.getSupply();
        expect(keySupply).toEqual(13n);


        let walletBalance = await walletContract.getBalance();
        expect(walletBalance).toEqual(10n);


        // selling 4 keys
        tradeKeyMsg = {
            $$type: 'TradeKey',
            subject: subject.address,
            supply: 13n,
            holder: holder.address,
            amount: 4n,
            increment: false,
            // a wrong balance
            balance: 7n,
        };

        const result = await shares.send(
            holder.getSender(),
            {
                value: gasConsumption,
            },
            tradeKeyMsg
        );

        const lastQueryId = await shares.getGetLastQueryId();
        console.log(lastQueryId)
        ///the query with that lastqueryId should be null
        const exist = await shares.getGetQueryExist(lastQueryId);
        console.log(exist)
    })


    it("should create allow holder to sell a key", async()=>{

        let price = await shares.getGetPrice(0n, 3n);
        let protocolFeePercentage = await shares.getGetFeePercentage();
        let subjectFeePercentage = await shares.getGetSubjectFeePercentage();

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

        await shares.send(
            subject.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            newKeyMsg
        );

        holder = await blockchain.treasury('holder');

        // buying 5 keys
        tradeKeyMsg = {
            $$type: 'TradeKey',
            subject: subject.address,
            supply: 3n,
            holder: holder.address,
            balance: 0n,
            amount: 5n,
            increment: true
        };

        price = await shares.getGetPrice(3n, 5n);
        protocolFeePercentage = await shares.getGetFeePercentage();
        subjectFeePercentage = await shares.getGetSubjectFeePercentage();

        // @ts-ignore
        protocolFee = price * protocolFeePercentage / 100n;
        // @ts-ignore
        subjectFee = price * subjectFeePercentage / 100n;

        await shares.send(
            holder.getSender(),
            {
                value: price + protocolFee + subjectFee + gasConsumption,
            },
            tradeKeyMsg
        );

        // selling 4 keys
        tradeKeyMsg = {
            $$type: 'TradeKey',
            subject: subject.address,
            supply: 8n,
            holder: holder.address,
            balance: 5n,
            amount: 4n,
            increment: false
        };

        // console.log("\n\n\n\n\n\n\n\n\n\n\n");

        const result = await shares.send(
            holder.getSender(),
            {
                value: gasConsumption,
            },
            tradeKeyMsg
        );

        expect(result.transactions).toHaveTransaction({
            from: holder.address,
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
        expect(keySupply).toEqual(4n);

        // wallet balance
        const walletAddress = await shares.getGetWalletAddress(holder.address, subject.address);
        expect(result.transactions).toHaveTransaction({
            from: shares.address,
            to: walletAddress,
            success: true
        })

        const walletContract = blockchain.openContract(await SharesWallet.fromAddress(walletAddress));

        const walletBalance = await walletContract.getBalance();
        expect(walletBalance).toEqual(1n);

    })

});
