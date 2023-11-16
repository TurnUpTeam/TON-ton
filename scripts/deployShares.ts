import { toNano } from 'ton-core';
import { Shares } from '../wrappers/Shares';
import { NetworkProvider } from '@ton-community/blueprint';

export async function run(provider: NetworkProvider) {
    const shares = provider.open(await Shares.fromInit());

    await shares.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(shares.address);

    // run methods on `shares`
}
