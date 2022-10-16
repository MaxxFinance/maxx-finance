import { ethers } from 'hardhat';
import log from 'ololog';

import { getMAXXGenesis } from '../utils/getContractInstance';

const fs = require('fs');

export async function setCodes(maxxGenesisAddress: string) {
    try {
        let hashedCodes: any[] = [];
        const maxxGenesis = await getMAXXGenesis(maxxGenesisAddress);
        fs.readFile(
            __dirname + '/codes.txt',
            async (error: any, data: string) => {
                if (error) {
                    throw error;
                }
                const codes = data.toString().toUpperCase();

                const codeArray = [];
                let i = 0;
                while (i < codes.length) {
                    log.red(codes.slice(i, i + 8));
                    codeArray.push(codes.slice(i, i + 8));
                    i += 9;
                }
                log.magenta('codeArray.length:', codeArray.length);

                for (let i = 0; i < 10; i++) {
                    let hash = ethers.utils.solidityKeccak256(
                        ['string'],
                        [codeArray[i]]
                    );
                    log.yellow('code:', codeArray[i], 'hash:', hash);
                }

                i = 0;
                while (i < 10000) {
                    for (let k = i; k < i + 500; k++) {
                        hashedCodes.push(
                            ethers.utils.solidityKeccak256(
                                ['string'],
                                [codeArray[k]]
                            )
                        );
                    }
                    let setGenesisCodes = await maxxGenesis.setCodes(
                        hashedCodes
                    );
                    await setGenesisCodes.wait();
                    log.yellow('Genesis codes set', setGenesisCodes.hash);
                    hashedCodes = [];

                    i += 500;
                }
            }
        );
    } catch (e) {
        log.red(e);
    }
}

async function hashCode() {
    let hash = ethers.utils.solidityKeccak256(['string'], ['a52FNKOU']);
    log.yellow('hash:', hash);

    const maxxGenesis = await getMAXXGenesis(maxxGenesisAddress);
}

const maxxGenesisAddress = process.env.MAXX_GENESIS_ADDRESS!;

setCodes(maxxGenesisAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

hashCode();
