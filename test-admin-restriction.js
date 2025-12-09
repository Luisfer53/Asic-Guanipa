const BASE_URL = 'http://localhost:3000/api/auth';

async function test() {
    try {
        
        console.log('1. Logging in as Admin...');
        const loginRes = await fetch(`${BASE_URL}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'admin@example.com', password: 'Password123' })
        });
        const loginData = await loginRes.json();

        if (!loginData.success) {
            console.error('Admin login failed:', loginData);
            return;
        }
        console.log('Admin login success. Token:', loginData.data.token ? 'Yes' : 'No');
        const adminToken = loginData.data.token;

        
        console.log('\n2. Registering new user (as Admin)...');
        const newUser = {
            username: 'newuser',
            email: 'newuser@example.com',
            password: 'Password123'
        };
        const registerRes = await fetch(`${BASE_URL}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${adminToken}`
            },
            body: JSON.stringify(newUser)
        });
        const registerData = await registerRes.json();
        console.log('Register response:', registerData);

        if (!registerData.success) {
            console.error('Registration failed unexpectedly');
        } else {
            console.log('Registration successful (Expected)');
        }

        
        console.log('\n3. Logging in as New User...');
        const userLoginRes = await fetch(`${BASE_URL}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: newUser.email, password: newUser.password })
        });
        const userLoginData = await userLoginRes.json();

        if (!userLoginData.success) {
            console.error('User login failed:', userLoginData);
            return;
        }
        console.log('User login success. Token:', userLoginData.data.token ? 'Yes' : 'No');
        const userToken = userLoginData.data.token;

        
        console.log('\n4. Try to register another user (as Non-Admin)...');
        const anotherUser = {
            username: 'another',
            email: 'another@example.com',
            password: 'Password123'
        };
        const failRegisterRes = await fetch(`${BASE_URL}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${userToken}`
            },
            body: JSON.stringify(anotherUser)
        });

        if (failRegisterRes.status === 403) {
            console.log('Registration failed with 403 (Expected)');
        } else {
            console.log('Registration status:', failRegisterRes.status);
            const failData = await failRegisterRes.json();
            console.log('Response:', failData);
        }

    } catch (err) {
        console.error('Test failed:', err);
    }
}

test();
