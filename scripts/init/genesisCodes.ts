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
                const codes = data.toString();

                const codeArray = [];
                let i = 0;
                while (i < codes.length) {
                    codeArray.push(codes.slice(i, i + 8));
                    i += 8;
                }
                log.yellow('codeArray:', codeArray[0]);

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

const maxxGenesisAddress = process.env.MAXX_GENESIS_ADDRESS!;

setCodes(maxxGenesisAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
