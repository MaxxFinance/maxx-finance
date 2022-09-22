export interface LeafInputs {
    address: string;
    amount: string;
}

export const freeClaimLeafInputs: LeafInputs[] = [
    {
        address: process.env.MAXX_VAULT_ADDRESS!,
        amount: '100000000000000000000000',
    },
    {
        address: process.env.OMEGA_ADDRESS!,
        amount: '65000000000',
    },
    {
        address: process.env.OMEGA_ADDRESS2!,
        amount: '34139486975',
    },
    {
        address: process.env.TEMRITE_ADDRESS!,
        amount: '20000000000000000000001',
    },
    {
        address: process.env.SON_OF_MOSIAH_ADDRESS!,
        amount: '1000000',
    },
    {
        address: '0xe3F641AD659249a020e2aF63c3f9aBd6cfFb668b',
        amount: '250000',
    },
];
