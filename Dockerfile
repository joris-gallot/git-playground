sFROM node:lts-alpine

# installe un simple serveur http pour servir un contenu statique
RUN pnpm install -g http-server

# définit le dossier 'app' comme dossier de travail
WORKDIR /appfront

# copie 'package.json' et 'package-lock.json' (si disponible)
COPY package*.json ./

# installe les dépendances du projet
RUN pnpm install

# copie les fichiers et dossiers du projet dans le dossier de travail (par exemple : le dossier 'app')
COPY . .

# construit l'app pour la production en la minifiant
RUN pnpm run build

EXPOSE 3000
CMD [ "http-server", "dist" ]