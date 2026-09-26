1. Clone this repo
2. Run `./install.sh` to install the tools I use
3. Run `./place.sh` to copy the associated config files into their appropriate places in your home directory (assumes same structure as on my mac). WARNING: the sync will overwrite any file that already exists at the same filepath. If you have parts of an existing config file you want to preserve, copy them into the repo files before running this script.

E.g.:

```bash
git clone https://github.com/tlmorgan24/config.git
cd config
chmod +x ./install.sh
./install.sh
chmod +x ./place.sh
./place.sh
cd ..
rm -r config
```