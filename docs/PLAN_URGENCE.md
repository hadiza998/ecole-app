# Lakol : plan d'urgence

Ce document dit quoi faire quand quelque chose tourne mal. Garde-le aussi dans un endroit sûr hors de GitHub (par exemple imprimé ou dans ton gestionnaire de mots de passe).

## Ce qui est sauvegardé, et où

| Quoi | Où | Fréquence | Durée de conservation |
|---|---|---|---|
| Toute la base (élèves, notes, paiements, comptes, journal) | GitHub, onglet **Actions**, fichier chiffré | Chaque jour à 03h17 UTC | 90 jours |
| Le code de l'application | GitHub | À chaque `git push` | Illimitée |
| Le plan de la base | `supabase/schema_complet.sql` dans le projet | À chaque nouvelle migration | Illimitée |
| Copie Supabase (plan Pro seulement) | Supabase, Database > Backups | Chaque jour | 7 jours |

Le fichier de sauvegarde est **chiffré** (AES-256). Sans le mot de passe `BACKUP_PASSPHRASE`, il est illisible, même pour GitHub. **Si tu perds ce mot de passe, les sauvegardes sont perdues.** Garde-le dans un gestionnaire de mots de passe ET sur papier, dans deux endroits différents.

Les 3 secrets à connaître (GitHub : dépôt > Settings > Secrets and variables > Actions) :
- `SUPABASE_DB_URL` : adresse de connexion à la base (Supabase > Connect > Session pooler).
- `BACKUP_PASSPHRASE` : mot de passe de chiffrement des sauvegardes.

## Chaque semaine (2 minutes)
1. GitHub > onglet **Actions** > « Sauvegarde quotidienne » : la dernière ligne doit être verte ✅. Si elle est rouge ❌, GitHub t'envoie aussi un email : corrige le jour même.
2. Vérifie qu'un fichier `sauvegarde-lakol-...` existe dans le dernier passage.

## Chaque trimestre : tester la restauration (30 minutes)
Une sauvegarde jamais testée n'est pas une sauvegarde.
1. Crée un projet Supabase **gratuit de test** (il ne sert qu'à ça).
2. Dans son SQL Editor, lance le contenu de `supabase/schema_complet.sql`.
3. Télécharge le dernier fichier de sauvegarde (GitHub > Actions > passage > Artifacts) et décompresse le .zip pour obtenir le fichier `.gpg`.
4. Dans le Terminal (il faut `postgresql` et `gpg` installés : `brew install libpq gnupg`) :
   ```
   BACKUP_PASSPHRASE='ton-mot-de-passe' bash scripts/restaurer.sh lakol_XXXX.dump.gpg "adresse-de-la-base-de-test"
   ```
5. Regarde dans le projet de test : les élèves, les notes et les comptes sont là. Puis supprime le projet de test.

## Urgence 1 : des données ont été effacées ou abîmées
1. **Ne rien supprimer de plus.** Note l'heure approximative du problème.
2. Regarde le **Journal** dans Lakol (menu directeur) : il dit qui a changé quoi, et quand.
3. Si les données sont perdues pour de bon : crée un nouveau projet Supabase, lance `supabase/schema_complet.sql`, puis restaure la dernière bonne sauvegarde (étapes du test ci-dessus, avec le vrai nouveau projet).
4. Dans le nouveau projet : mets les 2 clés (URL et clé publique) dans Netlify (Site configuration > Environment variables) et dans `.env.local`, puis redéploie.
5. Remets aussi dans Supabase les réglages d'authentification (voir « Réglages Supabase » ci-dessous).
6. Prévient les parents et les professeurs : les données saisies depuis la dernière sauvegarde (max. 24 h) sont à ressaisir.

## Urgence 2 : le directeur a perdu son téléphone (double authentification)
1. Supabase > **Authentication > Users** > clique sur l'utilisateur > supprime son « facteur » (MFA).
2. Il se reconnecte avec son mot de passe : Lakol lui fait refaire l'activation avec le nouveau téléphone.
3. Pense à garder la clé de secours affichée lors de l'activation, et à ajouter un 2e appareil.

## Urgence 3 : une clé secrète a fuité (SUPABASE_SERVICE_ROLE_KEY, BREVO_API_KEY, mot de passe de base)
1. Supabase > Project Settings > **API Keys** : régénère la clé secrète. Brevo : supprime la clé et crée-en une nouvelle.
2. Mets les nouvelles valeurs dans Netlify et `.env.local`, puis redéploie.
3. Supabase > Project Settings > Database : « Reset database password », puis mets à jour le secret GitHub `SUPABASE_DB_URL`.
4. Regarde le Journal : y a-t-il des modifications que personne ne reconnaît ?

## Urgence 4 : le compte d'un professeur ou d'un parent est piraté
1. Dans Lakol, le directeur **désactive** le compte (menu Professeurs). Il ne voit plus rien immédiatement.
2. Supabase > Authentication > Users : supprime ses sessions ou son compte.
3. Regarde le Journal pour voir ce qui a été modifié par ce compte, et corrige.

## Urgence 5 : Lakol ne répond plus
1. https://status.supabase.com et https://www.netlifystatus.com : est-ce une panne chez eux ?
2. Projet Supabase gratuit : il se met en **pause après environ 1 semaine sans activité**. Supabase > Restore project (les données sont gardées). Le plan Pro évite ça.
3. Netlify > Deploys : le dernier déploiement est-il en erreur ? Reviens au précédent (« Publish deploy »).

## Réglages Supabase à retrouver après une restauration
- Authentication > Sign In / Providers > Email : « Confirm email » activé, longueur minimale du mot de passe 10.
- Authentication > Multi-Factor : TOTP activé.
- Authentication > URL Configuration : l'adresse du site Netlify (+ `http://localhost:3000` pour tester).
- Authentication > SMTP Settings : l'envoi par Brevo.

## Objectifs (à ajuster)
- Perte de données maximale acceptable : 24 heures (sauvegarde quotidienne). Avec le plan Pro + récupération à la minute près : 2 minutes.
- Temps pour remettre en route : environ 2 heures avec ce plan.
