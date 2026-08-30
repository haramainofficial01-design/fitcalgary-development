import { CompleteMultipartUploadCommand, CreateMultipartUploadCommand, GetObjectCommand, HeadObjectCommand, S3Client, UploadPartCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';
import type { Env } from '../config/env.js';

const allowed=new Set(['video/mp4','video/quicktime','application/gpx+xml','image/jpeg','image/png']);
export class EvidenceStore {
  private readonly client:S3Client;
  constructor(private readonly env:Env){this.client=new S3Client({endpoint:env.S3_ENDPOINT,region:env.S3_REGION,forcePathStyle:true,credentials:{accessKeyId:env.S3_ACCESS_KEY_ID,secretAccessKey:env.S3_SECRET_ACCESS_KEY}});}
  validate(contentType:string,sizeBytes:number){if(!allowed.has(contentType))throw new Error('Unsupported evidence content type');if(!Number.isInteger(sizeBytes)||sizeBytes<1||sizeBytes>this.env.MAX_EVIDENCE_BYTES)throw new Error('Evidence size is outside the configured limit');}
  async begin(ownerSubject:string,submissionId:string,contentType:string,sizeBytes:number){this.validate(contentType,sizeBytes);const safeOwner=ownerSubject.replace(/[^a-zA-Z0-9_-]/g,'_');const key=`evidence/${safeOwner}/${submissionId}/${randomUUID()}`;const result=await this.client.send(new CreateMultipartUploadCommand({Bucket:this.env.S3_BUCKET,Key:key,ContentType:contentType,Metadata:{submission:submissionId}}));if(!result.UploadId)throw new Error('Storage provider did not create an upload');return{key,uploadId:result.UploadId};}
  async signPart(key:string,uploadId:string,partNumber:number){if(!Number.isInteger(partNumber)||partNumber<1||partNumber>10_000)throw new Error('Invalid multipart part number');return getSignedUrl(this.client,new UploadPartCommand({Bucket:this.env.S3_BUCKET,Key:key,UploadId:uploadId,PartNumber:partNumber}),{expiresIn:this.env.SIGNED_URL_TTL_SECONDS});}
  async complete(key:string,uploadId:string,parts:{ETag:string;PartNumber:number}[]){await this.client.send(new CompleteMultipartUploadCommand({Bucket:this.env.S3_BUCKET,Key:key,UploadId:uploadId,MultipartUpload:{Parts:parts}}));return this.client.send(new HeadObjectCommand({Bucket:this.env.S3_BUCKET,Key:key}));}
  async playbackUrl(key:string){return getSignedUrl(this.client,new GetObjectCommand({Bucket:this.env.S3_BUCKET,Key:key}),{expiresIn:this.env.SIGNED_URL_TTL_SECONDS});}
}
