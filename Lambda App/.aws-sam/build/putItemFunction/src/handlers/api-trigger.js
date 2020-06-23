
const axios = require('axios');
const url = process.env.API_URL;

exports.triggerHandler = async (event) => {
    
    await createItem()
    try {
       await createItem(true)
    } catch (e) {}

    return event;
};

async function createItem(fail=false){

   await axios.post(`${url}/awslab`, { "id": fail? getRandomInt(1,9999999999).toString(): getRandomInt(1,9999999999), "name": Math.random().toString(36).substring(7) })
}

function getRandomInt(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min + 1)) + min;
}
