import { MerkleTree } from 'merkletreejs';
import { utils } from 'ethers';
import keccak256 from 'keccak256';

export interface input {
    address: string;
    amount: string;
}

export const inputs: input[] = [
    {
        address: '0xBF7BF3d445aEc7B0c357163d5594DB8ca7C12D31',
        amount: '1000000',
    },
    {
        address: '0x087183a411770a645A96cf2e31fA69Ab89e22F5E',
        amount: '100000',
    },
    {
        address: '0xe3F641AD659249a020e2aF63c3f9aBd6cfFb668b',
        amount: '500000',
    },
    {
        address: '0xE84cbfd748FF3a24C0cD8A50eC147f971805bE67',
        amount: '4000',
    },
];

export function createMerkleTree(inputs: input[]): MerkleTree {
    const leaves = createLeaves(inputs);

    const merkleTree = new MerkleTree(leaves, keccak256, {
        sort: true,
    });

    return merkleTree;
}

export function createLeaves(inputs: input[]) {
    const leaves = inputs.map((x) =>
        utils.solidityKeccak256(['address', 'uint256'], [x.address, x.amount])
    );
    return leaves;
}
