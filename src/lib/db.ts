import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
const globalDb=globalThis as unknown as {prisma?:PrismaClient;pool?:Pool};
export const prisma=globalDb.prisma??new PrismaClient();
// pg does not recognize Prisma's schema URL parameter.
function pgUrl(){ const url=new URL(process.env.DATABASE_URL!); url.searchParams.delete('schema'); return url.toString(); }
export const pool=globalDb.pool??new Pool({connectionString:pgUrl(),max:8});
if(process.env.NODE_ENV!=='production'){ globalDb.prisma=prisma;globalDb.pool=pool; }
export function serialize(data:unknown){return JSON.parse(JSON.stringify(data,(_,v)=>typeof v==='bigint'?v.toString():v));}
