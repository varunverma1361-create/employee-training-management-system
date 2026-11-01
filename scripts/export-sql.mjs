import { readFileSync, writeFileSync } from 'node:fs';
const source=readFileSync('prisma/migrations/202610280001_foundation/migration.sql','utf8').replaceAll('\r\n','\n');
const header='-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.\n';
writeFileSync('sql/schema_reference.sql',header+source);
for(const part of ['schema','functions','triggers','views','indexes']) {
 const section=source.split('-- SECTION '+part+'\n')[1].split('-- SECTION ')[0];
 writeFileSync('sql/'+(part==='schema'?'constraints':part)+'.sql',header+section);
}
