import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-solhint';
import 'hardhat-docgen';

import * as dotenv from 'dotenv';
dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.16',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        polygon: {
            url: process.env.POLYGON_URL || '',
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
        mumbai: {
            url: process.env.MUMBAI_URL || '',
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
        hardhat: {
            forking: {
                url: process.env.POLYGON_URL || '',
            },
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: 'USD',
    },
    etherscan: {
        apiKey: {
            polygon: process.env.POLYGONSCAN_API_KEY!,
            polygonMumbai: process.env.POLYGONSCAN_API_KEY!,
        },
    },
    docgen: {
        path: './docs',
        clear: true,
        runOnCompile: true,
    },
};

export default config;
