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
                    for (let k = i; k < i + 100; k++) {
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

                    i += 100;
                }
            }
        );
    } catch (e) {
        log.red(e);
    }
}

const maxxGenesisAddress = '0x614346788721472b105DCBC676c4a5dbce710904';

setCodes(maxxGenesisAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
