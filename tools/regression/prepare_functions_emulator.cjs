/* Local dummy params for Functions discovery; never real service secrets. */
const fs=require('node:fs');
for(const [file,value] of [['functions/.env.local','GA4_PROPERTY_ID=0\nX_USERNAME=Derde_Div\n'],['functions/.secret.local','X_BEARER_TOKEN=local-emulator-placeholder\n']]){
 if(fs.existsSync(file))throw Error('Refusing to replace existing emulator parameters: '+file);
 fs.writeFileSync(file,value);
}
