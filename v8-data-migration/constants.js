import { createRequire } from 'module';

// Triple store constants
export const SCHEMA_CONTEXT = 'http://schema.org/';
export const METADATA_NAMED_GRAPH = 'metadata:graph';
export const PRIVATE_ASSERTION_ONTOLOGY =
    '<https://ontology.origintrail.io/dkg/1.0#privateAssertionID>';
export const TRIPLE_STORE_CONNECT_MAX_RETRIES = 10;
export const TRIPLE_STORE_CONNECT_RETRY_FREQUENCY = 10;
export const N_QUADS = 'application/n-quads';
export const OT_BLAZEGRAPH = 'ot-blazegraph';
export const OT_FUSEKI = 'ot-fuseki';
export const OT_GRAPHDB = 'ot-graphdb';
export const PRIVATE_CURRENT = 'privateCurrent';
export const PUBLIC_CURRENT = 'publicCurrent';
export const DKG_REPOSITORY = 'dkg';
export const VISIBILITY = {
    PUBLIC: 'public',
    PRIVATE: 'private',
};
export const BATCH_SIZE = 50;

export const DEFAULT_CONFIG_PATH = '/root/ot-node/current/config/config.json';
export const NODERC_CONFIG_PATH = '/root/ot-node/.origintrail_noderc';
export const DATA_MIGRATION_DIR = '/root/ot-node/data/data-migration';
export const LOG_DIR = '/root/ot-node/data/data-migration/logs';
export const ENV_PATH = '/root/ot-node/current/.env';
export const MIGRATION_DIR = '/root/ot-node/data/migrations/';
export const MIGRATION_PROGRESS_FILE = 'v8DataMigration';

export const DB_URLS = {
    testnet: 'https://hosting.origin-trail.network/csv/testnet.db',
    mainnet: '',
};

const require = createRequire(import.meta.url);

export const ABIs = {
    ContentAssetStorageV2: require('./abi/ContentAssetStorageV2.json'),
    ContentAssetStorage: require('./abi/ContentAssetStorage.json'),
};

export const BLOCKCHAINS = {
    BASE_DEVNET: {
        ID: 'base:84532',
        ENV: 'devnet',
        NAME: 'base_devnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0xBe08A25dcF2B68af88501611e5456571f50327B4',
    },
    BASE_TESTNET: {
        ID: 'base:84532',
        ENV: 'testnet',
        NAME: 'base_testnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0x9e3071Dc0730CB6dd0ce42969396D716Ea33E7e1',
    },
    BASE_MAINNET: {
        ID: 'base:8453',
        ENV: 'mainnet',
        NAME: 'base_mainnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0x3bdfA81079B2bA53a25a6641608E5E1E6c464597',
    },
    GNOSIS_DEVNET: {
        ID: 'gnosis:10200',
        ENV: 'devnet',
        NAME: 'gnosis_devnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0x3db64dD0Ac054610d1e2Af9Cca0fbCB1A7f4C2d8',
    },
    GNOSIS_TESTNET: {
        ID: 'gnosis:10200',
        ENV: 'testnet',
        NAME: 'gnosis_testnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0xeA3423e02c8d231532dab1BCE5D034f3737B3638',
    },
    GNOSIS_MAINNET: {
        ID: 'gnosis:100',
        ENV: 'mainnet',
        NAME: 'gnosis_mainnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0xf81a8C0008DE2DCdb73366Cf78F2b178616d11DD',
    },
    NEUROWEB_TESTNET: {
        ID: 'otp:20430',
        ENV: 'testnet',
        NAME: 'neuroweb_testnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0x1A061136Ed9f5eD69395f18961a0a535EF4B3E5f',
    },
    NEUROWEB_MAINNET: {
        ID: 'otp:2043',
        ENV: 'mainnet',
        NAME: 'neuroweb_mainnet',
        CONTENT_ASSET_STORAGE_CONTRACT_ADDRESS: '0x5cAC41237127F94c2D21dAe0b14bFeFa99880630',
    },
};

export const CONTENT_ASSET_STORAGE_CONTRACT = 'ContentAssetStorage';
