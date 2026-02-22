import path from 'path';

const TEST_BUCKET = 'mock-filebase-bucket';
let keyCounter = 0;

const sanitizeBaseName = (filename: string): string => {
    const ext = path.extname(filename).toLowerCase();
    return path
        .basename(filename, ext)
        .toLowerCase()
        .replace(/[^a-z0-9-_]/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '') || 'file';
};

const buildKey = (folder: string, filename: string): string => {
    const ext = path.extname(filename).toLowerCase() || '.bin';
    const base = sanitizeBaseName(filename);
    keyCounter += 1;
    return `${folder}/${base}/${String(keyCounter).padStart(5, '0')}${ext}`;
};

const buildPresignedUrl = (key: string, operation: 'GetObject' | 'PutObject'): string => {
    const encodedKey = key
        .split('/')
        .map((segment) => encodeURIComponent(segment))
        .join('/');

    const params = new URLSearchParams({
        'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
        'X-Amz-Credential': 'mock-access-key/20260222/us-east-1/s3/aws4_request',
        'X-Amz-Date': '20260222T000000Z',
        'X-Amz-Expires': '3600',
        'X-Amz-SignedHeaders': 'host',
        'X-Amz-Signature': `mock-signature-${operation.toLowerCase()}`,
        'x-id': operation,
    });

    return `https://s3.filebase.com/${TEST_BUCKET}/${encodedKey}?${params.toString()}`;
};

const sendMock = jest.fn(async (command: any) => ({
    $metadata: { httpStatusCode: 200 },
    key: command?.input?.Key,
    bucket: command?.input?.Bucket,
}));

jest.mock('@alias/config/s3-client', () => ({
    __esModule: true,
    default: {
        send: sendMock,
    },
}));

jest.mock('@alias/utils/fileUpload', () => {
    const getUploadUrl = jest.fn(async (folder: string, filename: string) => {
        const key = buildKey(folder, filename);
        return {
            key,
            uploadUrl: buildPresignedUrl(key, 'PutObject'),
        };
    });

    const getDownloadUrl = jest.fn(async (key: string) => buildPresignedUrl(key, 'GetObject'));

    const uploadFile = jest.fn(async (folder: string, file: Express.Multer.File) => {
        const originalname = file?.originalname || 'upload.bin';
        return buildKey(folder, originalname);
    });

    return {
        __esModule: true,
        getUploadUrl,
        getDownloadUrl,
        uploadFile,
    };
});
