const got = require('got');
const cheerio = require('cheerio');
const path = require('path');
const extract = require('extract-zip');
const fs = require('fs-extra');
const https = require('https');

const config = require('./config.json');

const pageUrl = "https://www.minecraft.net/en-us/download/server/bedrock";

var zip;
var output;

const platform = () => {
    if (config.platform.toLowerCase() == "windows") return 0;
    return 1;
}

got(pageUrl).then(res => {
    console.log('🔗 Extracting latest download link')
    const $ = cheerio.load(res.body);
    const downloadUrl = $('.downloadlink')[platform].attribs.href;
    zip = `versions/${path.posix.basename(downloadUrl)}`;
    var file = fs.WriteStream(zip);
    output = path.resolve('versions/output/');

    console.log('🔽 Downloading the latest version of BDS', zip);

    https.get(downloadUrl, res => {
        res.pipe(file);
    })
    file.on('finish', () => {
        console.log('📦 Backing up');
        config.doNotOverwrite.forEach(file => {
            fs.move(path.resolve(config.serverPath, file), path.resolve('backup/', file), err => {
                if (err) return console.error(err);
                // console.log('Backed up:', file);
            })
        })
        console.log('👽 Extracting');
        async function extraction() {
            try {
                await extract(zip, { dir: config.serverPath })

                console.log('📂 Restoring backup files');

                config.doNotOverwrite.forEach(file => {
                    fs.move(path.resolve('backup/', file), path.resolve(config.serverPath, file), { overwrite: true }, err => {
                        if (err) return console.error(err);
                        // console.log('Restored:', file);
                    })
                })
                console.log('✅ Done');
                
            } catch (err) {
                console.error(err);
            }
        }
        extraction();
    })
}).catch(err => {
    console.log(err);
})
