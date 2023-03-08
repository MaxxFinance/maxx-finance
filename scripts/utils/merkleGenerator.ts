import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs';
import { ethers } from 'ethers';

interface Leaf {
    address: string;
    amount: string;
    duration: string;
    name: string;
}

const INPUT_FILE = 'data.json';
const OUTPUT_FILE = 'tree.json';
const PROOFS_FILE = 'proofs.json';

const MERKLE_ROOT_INDEX = 0; // increment this to match the index of the merkle root in the array

async function readJsonFile(fileName: string) {
    const jsonString = await fs.promises.readFile(fileName);
    return JSON.parse(jsonString.toString());
}

async function createMerkleTree() {
    // (1) read leaves from json file
    const data: Leaf[] = await readJsonFile(INPUT_FILE);

    // (2) convert leaves to array of arrays
    const leaves = data.map(({ address, amount, duration, name }) => {
        return [address, amount, duration, name];
    });

    // (3) create merkle tree
    const tree = StandardMerkleTree.of(leaves, [
        'address',
        'uint256',
        'uint256',
        'string',
    ]);

    console.log(tree.root);

    // (4) write tree to json file
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(tree.dump()));

    // (5) return tree
    return tree;
}

async function getMerkleProofsFromFile() {
    // (1) read tree from json file
    const tree = StandardMerkleTree.load(
        JSON.parse(fs.readFileSync(OUTPUT_FILE).toString())
    );

    // (2) declare array to hold proofs
    const proofs = [];

    // (3) get proof for each leaf
    for (const [i, v] of tree.entries()) {
        const proof = tree.getProof(i);
        proofs.push(proof);
    }

    // (4) write proofs to json file
    fs.writeFileSync(PROOFS_FILE, JSON.stringify(proofs));
}

async function getMerkleProofsFromTree(tree: any) {
    // (1) declare array to hold proofs
    const proofs = [];

    // (2) get proof for each leaf
    for (const [i, v] of tree.entries()) {
        const proof = tree.getProof(i);
        const proofObject = {
            address: v[0],
            amount: v[1],
            duration: v[2],
            name: v[3],
            proof: proof,
            proofIndex: i,
            merkleRootIndex: MERKLE_ROOT_INDEX,
        };
        proofs.push(proofObject);
    }

    // (3) write proofs to json file
    fs.writeFileSync(PROOFS_FILE, JSON.stringify(proofs));
}

async function getMerkleProofFromFile(leafIndex: number) {
    // (1) read tree from json file
    const tree = StandardMerkleTree.load(
        JSON.parse(fs.readFileSync(OUTPUT_FILE).toString())
    );

    console.log('Merkle Root:', tree.root);

    // (2) get proof for leaf
    const proof = tree.getProof(leafIndex);

    // (3) return proof
    return proof;
}

async function getMerkleProofFromTree(tree: any, leafIndex: number) {
    // (1) get proof for leaf
    const proof = tree.getProof(leafIndex);

    // (2) return proof
    return proof;
}

async function main() {
    // (1) create merkle tree
    const tree = await createMerkleTree();

    // (2) get merkle proofs
    await getMerkleProofsFromTree(tree);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
