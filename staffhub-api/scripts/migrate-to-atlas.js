/**
 * Migrate all collections from local MongoDB to MongoDB Atlas.
 *
 * Usage:
 *   1. Add MONGODB_URI_ATLAS to staffhub-api/.env
 *   2. npm run migrate:atlas
 *   3. Optional: npm run migrate:atlas -- --dry-run
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

const SOURCE_URI = process.env.MONGODB_URI_SOURCE || 'mongodb://localhost:27017/staffhub';
const TARGET_URI = process.env.MONGODB_URI_ATLAS;
const dryRun = process.argv.includes('--dry-run');

function maskUri(uri) {
  return String(uri).replace(/:([^:@/]+)@/, ':****@');
}

async function listCollectionStats(conn) {
  const cols = await conn.db.listCollections().toArray();
  const stats = [];
  for (const { name } of cols) {
    if (name.startsWith('system.')) continue;
    const count = await conn.db.collection(name).countDocuments();
    stats.push({ name, count });
  }
  return stats.sort((a, b) => a.name.localeCompare(b.name));
}

async function copyIndexes(sourceCol, targetCol) {
  const indexes = await sourceCol.indexes();
  for (const idx of indexes) {
    if (idx.name === '_id_') continue;
    const { key, name, unique, sparse, expireAfterSeconds } = idx;
    const options = { name };
    if (unique) options.unique = true;
    if (sparse) options.sparse = true;
    if (expireAfterSeconds != null) options.expireAfterSeconds = expireAfterSeconds;
    try {
      await targetCol.createIndex(key, options);
    } catch (err) {
      console.warn(`  Index warning (${name}): ${err.message}`);
    }
  }
}

async function main() {
  if (!dryRun && !TARGET_URI) {
    console.error('\n[ERROR] MONGODB_URI_ATLAS is not set in staffhub-api/.env\n');
    console.error('Add your Atlas connection string, e.g.:');
    console.error('MONGODB_URI_ATLAS=mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/staffhub?retryWrites=true&w=majority\n');
    process.exit(1);
  }

  if (TARGET_URI && SOURCE_URI === TARGET_URI) {
    console.error('[ERROR] Source and target URIs are the same. Aborting.');
    process.exit(1);
  }

  console.log('Staff Hub — MongoDB migration');
  console.log('  Source:', maskUri(SOURCE_URI));
  console.log('  Target:', TARGET_URI ? maskUri(TARGET_URI) : '(not set)');
  console.log('  Mode:  ', dryRun ? 'DRY RUN (no writes)' : 'LIVE');
  console.log('');

  let sourceConn;
  let targetConn;

  try {
    console.log('Connecting to source...');
    sourceConn = mongoose.createConnection(SOURCE_URI);
    await sourceConn.asPromise();

    const sourceStats = await listCollectionStats(sourceConn);
    if (sourceStats.every((s) => s.count === 0)) {
      console.error('[ERROR] Source database has no documents to migrate.');
      process.exit(1);
    }

    console.log('\nSource collections:');
    for (const { name, count } of sourceStats) {
      console.log(`  ${name}: ${count}`);
    }

    if (dryRun) {
      if (!TARGET_URI) {
        console.log('\nDry run complete — source OK. Add MONGODB_URI_ATLAS to .env then run: npm run migrate:atlas');
      } else {
        console.log('\nConnecting to target (Atlas) for dry run...');
        targetConn = mongoose.createConnection(TARGET_URI);
        await targetConn.asPromise();
        console.log('Target connection OK.');
        console.log('\nDry run complete — no data written.');
      }
      return;
    }

    console.log('Connecting to target (Atlas)...');
    targetConn = mongoose.createConnection(TARGET_URI);
    await targetConn.asPromise();

    const targetBefore = await listCollectionStats(targetConn);
    const targetTotal = targetBefore.reduce((sum, s) => sum + s.count, 0);
    if (targetTotal > 0) {
      console.log('\n[WARN] Target database is not empty:');
      for (const { name, count } of targetBefore) {
        if (count > 0) console.log(`  ${name}: ${count}`);
      }
      console.log('  Existing target documents in these collections will be replaced.\n');
    }

    console.log('\nMigrating...');
    let totalDocs = 0;

    for (const { name, count } of sourceStats) {
      if (count === 0) {
        console.log(`  ${name}: skipped (empty)`);
        continue;
      }

      const sourceCol = sourceConn.db.collection(name);
      const targetCol = targetConn.db.collection(name);
      const docs = await sourceCol.find({}).toArray();

      await targetCol.deleteMany({});
      if (docs.length > 0) {
        await targetCol.insertMany(docs, { ordered: false });
      }
      await copyIndexes(sourceCol, targetCol);

      totalDocs += docs.length;
      console.log(`  ${name}: ${docs.length} document(s)`);
    }

    const targetAfter = await listCollectionStats(targetConn);
    console.log('\nTarget after migration:');
    for (const { name, count } of targetAfter) {
      console.log(`  ${name}: ${count}`);
    }

    console.log(`\nDone. Migrated ${totalDocs} document(s) to Atlas.`);
    console.log('\nNext steps:');
    console.log('  1. Set MONGODB_URI on Render to the same Atlas URI');
    console.log('  2. Keep JWT_SECRET the same if you want existing tokens to work');
    console.log('  3. Rebuild mobile APK with PRODUCTION_API_URL pointing to Render');
  } catch (err) {
    console.error('\n[ERROR]', err.message);
    if (err.message.includes('querySrv ECONNREFUSED') || err.message.includes('ECONNREFUSED')) {
      console.error('\nWindows DNS issue with mongodb+srv://');
      console.error('  In Atlas: Connect → Drivers → copy the NON-SRV connection string');
      console.error('  (lists ac-xxxx-shard-00-00... hosts). Include /staffhub before ?');
      console.error('  Or set dns to 8.8.8.8 and retry mongodb+srv.');
    }
    if (err.message.includes('timed out') || err.message.includes('ENOTFOUND')) {
      console.error('\nAtlas connection tips:');
      console.error('  - Network Access → Allow 0.0.0.0/0');
      console.error('  - URL-encode special characters in password (@ → %40)');
      console.error('  - Use standard mongodb://... URI if mongodb+srv fails');
    }
    process.exit(1);
  } finally {
    if (sourceConn) await sourceConn.close();
    if (targetConn) await targetConn.close();
  }
}

main();
