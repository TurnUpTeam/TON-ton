import { Address, toNano } from 'ton-core';
import { Counter } from '../_sullof/Counter';
import { NetworkProvider, sleep } from '@ton-community/blueprint';

export async function run(provider: NetworkProvider, args: string[]) {
    const ui = provider.ui();

    const address = Address.parse(args.length > 0 ? args[0] : await ui.input('Counter address'));

    if (!(await provider.isContractDeployed(address))) {
        ui.write(`Error: Contract at address ${address} is not deployed!`);
        return;
    }

    const counter = provider.open(Counter.fromAddress(address));

    const counterBefore = await counter.getCounter();

    ui.write('Counter value: ' + counterBefore);
}
