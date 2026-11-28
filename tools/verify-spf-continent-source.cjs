const fs=require("fs"),crypto=require("crypto"),path=require("path");
const ref=Object.fromEntries(fs.readFileSync(path.join(__dirname,"spf-1.49.2-continent-blobs.tsv"),"utf8").trim().split(/\r?\n/).map(row=>row.split("\t")));
const dir=process.argv[2];
let failed=[];
const names=fs.readdirSync(dir).filter(f=>/^Nav[01](?:_\d+)?\.lua$/.test(f));
if(names.length!==Object.keys(ref).length || Object.keys(ref).some(p=>!names.includes(path.basename(p))))throw Error("source file set mismatch");
for(const f of fs.readdirSync(dir).filter(f=>/^Nav[01](?:_\d+)?\.lua$/.test(f))){
 const orig=fs.readFileSync(path.join(dir,f),"utf8").replace(/\r\n/g,"\n");
 const trim=orig.replace(/^local ForeverCoreHostChunk = function\(\.\.\.\) /,"").replace(/\nend local _, ForeverCoreHostNs = [^\n]*\n*$/,"\n");
 const hash=b=>crypto.createHash("sha1").update("blob "+Buffer.byteLength(b)+"\0").update(b).digest("hex");
 const options=[trim,trim.trimEnd()+"\n",trim.trimEnd(),trim.trimEnd()+"\n\n",orig];
 if(!options.some(x=>hash(x)===ref["Nav/"+f]))failed.push(f);
}
console.log("unverified files:",failed);
if(failed.length)process.exit(1);

