import { PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import client from '@alias/config/s3-client'
import { config } from '@alias/config'
import path from 'path'

function buildS3Key(folder:string, originalName: string) {
    const ext = path.extname(originalName).toLowerCase();
    const filename = path
        .basename(originalName, ext)
        .toLowerCase()
        .replace(/[^a-z0-9-_]/g, "-");

    const suffix = Math.random().toString(36).slice(2, 2 + 5);

    return `${folder}/${filename}/${suffix}${ext}`;
}

export async function getUploadUrl(folder:string, filename: string, type: string) {
    if (!config.bucketName) {
        throw new Error('S3_BUCKET_NAME is not configured');
    }
    const key = buildS3Key(folder, filename);
    const command = new PutObjectCommand({
        Bucket: config.bucketName,
        Key: key,
        ContentType: type,
    });
    const uploadUrl = await getSignedUrl(client, command, { expiresIn: 3600 })
    return { uploadUrl, key }
}

export async function getDownloadUrl(key: string) {
    if (!config.bucketName) {
        throw new Error('S3_BUCKET_NAME is not configured');
    }
    const command = new GetObjectCommand({
        Bucket: config.bucketName,
        Key: key,
    });

    return getSignedUrl(client, command, { expiresIn: 3600 });
}

export async function uploadFile(folder:string, file: Express.Multer.File) {
    const { uploadUrl, key } = await getUploadUrl(folder, file.originalname, file.mimetype);
    const response = await fetch(uploadUrl, {
        method: "PUT",
        body: file.buffer,
        headers: {
            "Content-Type": file.mimetype,
        },
    });
    if (!response.ok) {
        throw new Error(`File upload failed with status ${response.status}`);
    }
    return key;
}
