import { MerkleTree } from 'merkletreejs';
import { utils } from 'ethers';
import keccak256 from 'keccak256';

import { LeafInputs } from './freeClaimLeaves';

export function createLeaves(freeClaimLeafInputs: LeafInputs[]) {
    const leaves = freeClaimLeafInputs.map((x) =>
        utils.solidityKeccak256(['address', 'uint256'], [x.address, x.amount])
    );
    return leaves;
}

export function getMerkleRoot(freeClaimLeafInputs: LeafInputs[]): string {
    const merkleTree = generateMerkleTree(freeClaimLeafInputs);
    return merkleTree.getHexRoot().toString();
}

export function generateMerkleTree(
    freeClaimLeafInputs: LeafInputs[]
): MerkleTree {
    const leaves = createLeaves(freeClaimLeafInputs);
    const merkleTree = new MerkleTree(leaves, keccak256, {
        sort: true,
    });
    return merkleTree;
}

export function verifyMerkleRoot(
    freeClaimLeafInputs: LeafInputs[],
    merkleRoot: string
): boolean {
    const merkleTree = generateMerkleTree(freeClaimLeafInputs);
    const rootHash = merkleTree.getHexRoot();
    return rootHash === merkleRoot;
}
