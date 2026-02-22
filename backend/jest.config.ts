import type { Config } from "jest";

const config: Config = {
    testEnvironment: "node",
    roots: ["<rootDir>/tests"],
    setupFilesAfterEnv: ["<rootDir>/tests/setup/global-mocks.ts"],
    moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
    extensionsToTreatAsEsm: [".ts"],
    transform: {
        "^.+\\.(ts|tsx)$": [
            "ts-jest",
            {
                tsconfig: "<rootDir>/tsconfig.json",
                useESM: true
            }
        ]
    },
    moduleNameMapper: {
        "^@alias/(.*)$": "<rootDir>/src/$1"
    },
    collectCoverageFrom: ["src/**/*.ts", "!src/**/index.ts", "!src/**/types/**"],
    coverageDirectory: "coverage",
    coverageThreshold: {
        global: {
            branches: 18,
            functions: 30,
            lines: 32,
            statements: 32
        }
    },
    reporters: ["default"],
    forceExit: true,
    clearMocks: true,
};

export default config;
