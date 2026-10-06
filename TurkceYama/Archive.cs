using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;
public static class TranslationArchive {
 static byte[] Zlib(byte[] raw) {
  using(var ms=new MemoryStream()) {
   ms.WriteByte(0x78); ms.WriteByte(0x9c);
   using(var ds=new DeflateStream(ms,CompressionMode.Compress,true)) ds.Write(raw,0,raw.Length);
   uint a=1,b=0; foreach(byte v in raw) { a=(a+v)%65521; b=(b+a)%65521; }
   uint sum=(b<<16)|a;
   ms.WriteByte((byte)(sum>>24));ms.WriteByte((byte)(sum>>16));ms.WriteByte((byte)(sum>>8));ms.WriteByte((byte)sum);
   return ms.ToArray();
  }
 }
 public static void Build(string source,string output,string[] names,string[] files) {
  var replacements=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
  for(int i=0;i<names.Length;i++) replacements.Add(names[i],files[i]);
  using(var input=File.OpenRead(source)) using(var r=new BinaryReader(input)) {
   uint v1=r.ReadUInt32(),v2=r.ReadUInt32(),v3=r.ReadUInt32(); byte flag1=r.ReadByte(),flag2=r.ReadByte();
   uint dataStart=r.ReadUInt32(),nameLength=r.ReadUInt32();
   if(v1!=5||v2!=1||v3!=4||nameLength>10000000) throw new Exception("Unsupported DV2 header: "+source);
   byte[] nameBlock=r.ReadBytes((int)nameLength);
   string[] archiveNames=Encoding.GetEncoding(28591).GetString(nameBlock).Split(new char[]{'\0'},StringSplitOptions.RemoveEmptyEntries);
   uint count=r.ReadUInt32(); if(count!=archiveNames.Length||count>1000000) throw new Exception("Invalid archive table");
   var offsets=new uint[count]; var sizes=new uint[count]; var rawSizes=new uint[count];
   for(int i=0;i<count;i++){offsets[i]=r.ReadUInt32();sizes[i]=r.ReadUInt32();rawSizes[i]=r.ReadUInt32();if((long)dataStart+offsets[i]+sizes[i]>input.Length)throw new Exception("Invalid archive entry");}
   var packed=new Dictionary<int,byte[]>();
   for(int i=0;i<count;i++) { string path;
    if(replacements.TryGetValue(archiveNames[i],out path)) {byte[] raw=File.ReadAllBytes(path);packed[i]=Zlib(raw);sizes[i]=(uint)packed[i].Length;rawSizes[i]=(uint)raw.Length;replacements.Remove(archiveNames[i]);}
   }
   if(replacements.Count!=0) throw new Exception("Translation entry missing from original archive: "+String.Join(", ",replacements.Keys));
   uint tableEnd=26+nameLength+12*count;
   uint newStart=Math.Max(dataStart,tableEnd);
   using(var outputFile=File.Create(output)) using(var w=new BinaryWriter(outputFile)) {
    w.Write(v1);w.Write(v2);w.Write(v3);w.Write(flag1);w.Write(flag2);w.Write(newStart);w.Write(nameLength);w.Write(nameBlock);w.Write(count);
    uint next=0; for(int i=0;i<count;i++){w.Write(next);w.Write(sizes[i]);w.Write(rawSizes[i]);next=checked(next+sizes[i]);}
    if(dataStart>tableEnd) {input.Position=tableEnd;byte[] padding=r.ReadBytes((int)(dataStart-tableEnd));w.Write(padding);}
    outputFile.Position=newStart;
    for(int i=0;i<count;i++) {byte[] data;
     if(!packed.TryGetValue(i,out data)) {input.Position=(long)dataStart+offsets[i];data=r.ReadBytes((int)sizes[i]);if(data.Length!=sizes[i])throw new Exception("Truncated archive");}
     w.Write(data);
    }
   }
  }
 }
}