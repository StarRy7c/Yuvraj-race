document.addEventListener('DOMContentLoaded', () => {
    // DOM Elements
    const canvas = document.getElementById('gameCanvas');
    const ctx = canvas.getContext('2d');

    const scoreDisplay = document.getElementById('score');
    const distanceDisplay = document.getElementById('distance');
    const finalScoreDisplay = document.getElementById('finalScore');
    const finalDistanceDisplay = document.getElementById('finalDistance');

    const startScreen = document.getElementById('startScreen');
    const gameOverScreen = document.getElementById('gameOverScreen');
    const startButton = document.getElementById('startButton');
    const retryButton = document.getElementById('retryButton');

    const controlLeftButton = document.getElementById('controlLeft');
    const controlRightButton = document.getElementById('controlRight');

    // Audio Elements
    const engineSound = document.getElementById('engineSound');
    const crashSound = document.getElementById('crashSound');
    // const winSound = document.getElementById('winSound'); // If you have a win condition
    const backgroundMusic = document.getElementById('backgroundMusic');

    // Game State
    let gameRunning = false;
    let gameOver = false;
    let score = 0;
    let distance = 0;
    let gameSpeed = 2; // Initial speed for background/obstacles
    let speedIncreaseTimer = 0;
    const speedIncreaseInterval = 300; // Increase speed every 5 seconds (300 frames at 60fps)
    const maxGameSpeed = 10;

    let animationFrameId;

    // Player Car
    const carWidth = 50;
    const carHeight = 80;
    let carX = canvas.width / 2 - carWidth / 2;
    const carY = canvas.height - carHeight - 30; // Positioned near the bottom
    const carMoveSpeed = 7;
    let carImage; // To be loaded

    // Obstacles
    let obstacles = [];
    const obstacleWidth = 60;
    const obstacleHeight = 40;
    const obstacleSpawnInterval = 120; // Frames between spawns (2 seconds at 60fps)
    let obstacleSpawnTimer = 0;
    const obstacleColors = ['#ff4444', '#ffbb33', '#aa66cc']; // Example colors

    // Background Elements (Road lines, Stars, etc.)
    let roadLines = [];
    const roadLineWidth = 5;
    const roadLineHeight = 30;
    const roadLineGap = 30;
    let stars = [];

    // Controls State
    let moveLeft = false;
    let moveRight = false;

    // --- PRELOAD ASSETS ---
    function preloadAssets() {
        let assetsLoaded = 0;
        const totalAssets = 1; // Increment this if you add more images

        carImage = new Image();
        carImage.src = 'car.png'; // <<< IMPORTANT: Create or find a car.png (top-down view)
        carImage.onload = () => {
            assetLoaded();
        };
        // carImage.onerror = () => console.error("Failed to load car.png");

        // Add more asset loading here (e.g., obstacle images)

        function assetLoaded() {
            assetsLoaded++;
            if (assetsLoaded === totalAssets) {
                // All assets loaded, enable start button or auto-start
                startButton.disabled = false;
                startButton.textContent = "Start Game";
                console.log("Assets loaded.");
            }
        }
        startButton.disabled = true;
        startButton.textContent = "Loading Assets...";
    }
    preloadAssets(); // Call preload function


    // --- INITIALIZATION ---
    function setCanvasDimensions() {
        const gameContainer = document.getElementById('gameContainer');
        canvas.width = gameContainer.clientWidth;
        canvas.height = gameContainer.clientHeight;
        // Update car position if canvas resizes while game isn't running
        if (!gameRunning) {
            carX = canvas.width / 2 - carWidth / 2;
        }
    }

    function initGame() {
        gameOver = false;
        gameRunning = true;
        score = 0;
        distance = 0;
        gameSpeed = 2;
        speedIncreaseTimer = 0;
        carX = canvas.width / 2 - carWidth / 2;
        obstacles = [];
        roadLines = [];
        stars = []; // Re-initialize stars for dynamic effect

        scoreDisplay.textContent = score;
        distanceDisplay.textContent = Math.floor(distance) + 'm';

        startScreen.style.display = 'none';
        gameOverScreen.style.display = 'none';

        // Initialize road lines
        for (let i = 0; i < canvas.height / (roadLineHeight + roadLineGap) + 2; i++) {
            roadLines.push({
                x: canvas.width / 2 - roadLineWidth / 2,
                y: i * (roadLineHeight + roadLineGap) - (roadLineHeight + roadLineGap) // Start some off-screen
            });
        }

        // Initialize stars for background
        for (let i = 0; i < 50; i++) { // Number of stars
            stars.push({
                x: Math.random() * canvas.width,
                y: Math.random() * canvas.height,
                size: Math.random() * 2 + 1, // Star size
                opacity: Math.random() * 0.5 + 0.3 // Star opacity
            });
        }

        // Start Sounds
        playBackgroundMusic();
        playEngineSound();

        gameLoop();
    }

    // --- SOUNDS ---
    function playEngineSound() {
        engineSound.currentTime = 0;
        engineSound.volume = 0.3; // Adjust volume
        engineSound.play().catch(e => console.log("Engine sound play failed:", e));
    }

    function stopEngineSound() {
        engineSound.pause();
    }

    function playCrashSound() {
        crashSound.currentTime = 0;
        crashSound.volume = 0.5;
        crashSound.play().catch(e => console.log("Crash sound play failed:", e));
    }

    function playBackgroundMusic() {
        backgroundMusic.volume = 0.2; // Adjust volume
        backgroundMusic.play().catch(e => console.log("Background music play failed:", e));
    }

    function stopBackgroundMusic() {
        backgroundMusic.pause();
    }


    // --- GAME CONTROLS ---
    function handleKeyDown(e) {
        if (!gameRunning && e.key === 'Enter' && startScreen.style.display !== 'none') {
            startButton.click(); // Allow starting with Enter
            return;
        }
        if (!gameRunning && e.key === 'Enter' && gameOverScreen.style.display !== 'none') {
            retryButton.click(); // Allow retrying with Enter
            return;
        }

        if (!gameRunning) return;

        if (e.key === 'ArrowLeft' || e.key === 'a') {
            moveLeft = true;
        } else if (e.key === 'ArrowRight' || e.key === 'd') {
            moveRight = true;
        }
    }

    function handleKeyUp(e) {
        if (e.key === 'ArrowLeft' || e.key === 'a') {
            moveLeft = false;
        } else if (e.key === 'ArrowRight' || e.key === 'd') {
            moveRight = false;
        }
    }

    // Touch Controls
    let touchStartX = 0;
    const touchThreshold = 30; // Minimum swipe distance

    function handleTouchStart(e) {
        if (!gameRunning) return;
        touchStartX = e.touches[0].clientX;
        // For on-screen buttons, prevent default to avoid double actions or page scroll
        if (e.target === controlLeftButton || e.target === controlRightButton) {
            e.preventDefault();
        }
    }

    function handleTouchMove(e) {
        if (!gameRunning || !touchStartX) return;
        e.preventDefault(); // Prevent scrolling while swiping
        let touchCurrentX = e.touches[0].clientX;
        let diffX = touchCurrentX - touchStartX;

        if (diffX > touchThreshold) { // Swipe Right
            moveRight = true;
            moveLeft = false; // Ensure only one direction
        } else if (diffX < -touchThreshold) { // Swipe Left
            moveLeft = true;
            moveRight = false; // Ensure only one direction
        }
        // For continuous movement while finger is held on button:
        // (This might be better if the buttons directly set moveLeft/moveRight on mousedown/touchstart)
    }

    function handleTouchEnd(e) {
        // If not using on-screen buttons, or to stop movement when swipe ends
        // moveLeft = false;
        // moveRight = false;
        touchStartX = 0; // Reset touch start position

        // If touch ends and it wasn't on a button, ensure movement stops
        // This helps if a swipe ends mid-air without hitting a button.
        if (e.target !== controlLeftButton && e.target !== controlRightButton) {
            // moveLeft = false; // Could be too abrupt, test usability
            // moveRight = false;
        }
    }

    // On-screen button controls
    controlLeftButton.addEventListener('mousedown', () => moveLeft = true);
    controlLeftButton.addEventListener('mouseup', () => moveLeft = false);
    controlLeftButton.addEventListener('mouseleave', () => moveLeft = false); // Stop if mouse leaves button
    controlLeftButton.addEventListener('touchstart', (e) => { e.preventDefault(); moveLeft = true; });
    controlLeftButton.addEventListener('touchend', (e) => { e.preventDefault(); moveLeft = false; });

    controlRightButton.addEventListener('mousedown', () => moveRight = true);
    controlRightButton.addEventListener('mouseup', () => moveRight = false);
    controlRightButton.addEventListener('mouseleave', () => moveRight = false);
    controlRightButton.addEventListener('touchstart', (e) => { e.preventDefault(); moveRight = true; });
    controlRightButton.addEventListener('touchend', (e) => { e.preventDefault(); moveRight = false; });


    // --- UPDATE GAME ELEMENTS ---
    function updateCarPosition() {
        if (moveLeft && carX > 0) {
            carX -= carMoveSpeed;
        }
        if (moveRight && carX < canvas.width - carWidth) {
            carX += carMoveSpeed;
        }
        // Keep car within boundaries (redundant if checks above are strict, but good for safety)
        carX = Math.max(0, Math.min(canvas.width - carWidth, carX));
    }

    function updateRoadLines() {
        for (let i = roadLines.length - 1; i >= 0; i--) {
            roadLines[i].y += gameSpeed;
            if (roadLines[i].y > canvas.height) {
                // Move line to top, recycle
                roadLines[i].y = -roadLineHeight - roadLineGap + (roadLines[i].y - canvas.height);
            }
        }
    }

    function updateStars() {
        stars.forEach(star => {
            star.y += gameSpeed * 0.2; // Slower parallax for stars
            if (star.y > canvas.height) {
                star.y = 0;
                star.x = Math.random() * canvas.width;
            }
        });
    }

    function spawnObstacle() {
        // Spawn obstacles from either left, middle, or right lane (conceptually)
        const laneWidth = canvas.width / 3;
        const spawnLane = Math.floor(Math.random() * 3); // 0, 1, or 2
        let obsX = spawnLane * laneWidth + (laneWidth / 2) - (obstacleWidth / 2);
        // Add slight random horizontal offset within the lane
        obsX += (Math.random() - 0.5) * (laneWidth * 0.3);
        obsX = Math.max(0, Math.min(canvas.width - obstacleWidth, obsX)); // Ensure within canvas

        const color = obstacleColors[Math.floor(Math.random() * obstacleColors.length)];
        obstacles.push({ x: obsX, y: -obstacleHeight, width: obstacleWidth, height: obstacleHeight, color: color });
    }

    function updateObstacles() {
        obstacleSpawnTimer++;
        if (obstacleSpawnTimer >= obstacleSpawnInterval / (gameSpeed / 2)) { // Spawn faster as speed increases
            spawnObstacle();
            obstacleSpawnTimer = 0;
        }

        for (let i = obstacles.length - 1; i >= 0; i--) {
            obstacles[i].y += gameSpeed;
            // Remove obstacles that have passed and increment score
            if (obstacles[i].y > canvas.height) {
                obstacles.splice(i, 1);
                score += 10;
                scoreDisplay.textContent = score;
            }
        }
    }

    function checkCollisions() {
        for (let obs of obstacles) {
            // Simple AABB collision detection
            if (
                carX < obs.x + obs.width &&
                carX + carWidth > obs.x &&
                carY < obs.y + obs.height &&
                carY + carHeight > obs.y
            ) {
                triggerGameOver();
                break;
            }
        }
    }

    function updateGameSpeed() {
        speedIncreaseTimer++;
        if (speedIncreaseTimer >= speedIncreaseInterval && gameSpeed < maxGameSpeed) {
            gameSpeed += 0.5;
            speedIncreaseTimer = 0;
            console.log("Game speed increased to:", gameSpeed);
            // Adjust engine sound pitch or volume based on speed (optional advanced feature)
            // engineSound.playbackRate = 1 + (gameSpeed - 2) / 10; // Example
        }
        distance += gameSpeed / 60; // Assuming 60 FPS, distance in meters per frame
        distanceDisplay.textContent = Math.floor(distance) + 'm';
    }


    // --- DRAWING ---
    function drawCar() {
        if (carImage && carImage.complete) {
             // Simple wobble/tilt effect when turning (optional)
            let tilt = 0;
            if (moveLeft) tilt = -5; // degrees
            if (moveRight) tilt = 5; // degrees

            ctx.save();
            ctx.translate(carX + carWidth / 2, carY + carHeight / 2);
            ctx.rotate(tilt * Math.PI / 180);
            ctx.drawImage(carImage, -carWidth / 2, -carHeight / 2, carWidth, carHeight);
            ctx.restore();
        } else {
            // Fallback if image not loaded (or for placeholder)
            ctx.fillStyle = '#0099cc'; // Neon blue
            ctx.fillRect(carX, carY, carWidth, carHeight);
            ctx.strokeStyle = '#00ffff';
            ctx.lineWidth = 2;
            ctx.strokeRect(carX, carY, carWidth, carHeight);
        }
    }

    function drawRoadLines() {
        ctx.fillStyle = 'rgba(200, 200, 200, 0.7)'; // Semi-transparent white lines
        roadLines.forEach(line => {
            ctx.fillRect(line.x, line.y, roadLineWidth, roadLineHeight);
        });
        // Draw solid side lines (shoulders of the road)
        const shoulderWidth = 10; // Width of the road shoulder
        ctx.fillStyle = 'rgba(80, 80, 90, 0.6)'; // Darker grey for shoulders
        ctx.fillRect(0, 0, shoulderWidth, canvas.height);
        ctx.fillRect(canvas.width - shoulderWidth, 0, shoulderWidth, canvas.height);
    }

    function drawStars() {
        stars.forEach(star => {
            ctx.fillStyle = `rgba(255, 255, 255, ${star.opacity})`;
            ctx.beginPath();
            ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
            ctx.fill();
        });
    }

    function drawStreetlights() {
        // This is a conceptual placeholder.
        // True dynamic streetlights would require more complex perspective drawing.
        // For a simpler effect, you could draw static or slowly moving shapes at road sides.
        const lightHeight = canvas.height * 0.3;
        const lightWidth = 10;
        const numLights = 3; // Per side, visible at a time

        for (let i = 0; i < numLights; i++) {
            const yPosBase = (canvas.height / numLights) * i;
            // Simulate movement by offsetting Y based on gameSpeed
            // Modulo ensures they loop around
            let yPos = (yPosBase - (distance * 10) % (canvas.height + lightHeight)) % (canvas.height + lightHeight);
            if (yPos < -lightHeight) yPos += (canvas.height + lightHeight);


            // Left streetlight
            ctx.fillStyle = '#444'; // Pole
            ctx.fillRect(15, yPos - lightHeight * 0.8, lightWidth / 2, lightHeight * 0.8);
            ctx.beginPath(); // Light glow
            ctx.arc(20 + lightWidth /2 , yPos - lightHeight * 0.8, 20, 0, Math.PI * 2);
            ctx.fillStyle = 'rgba(255, 223, 186, 0.15)'; // Soft yellow glow
            ctx.fill();
            ctx.fillStyle = 'yellow'; // Light source
            ctx.fillRect(18 + lightWidth/2 - 5, yPos - lightHeight * 0.8 -5, 10, 10);


            // Right streetlight
            ctx.fillStyle = '#444';
            ctx.fillRect(canvas.width - 15 - (lightWidth / 2), yPos - lightHeight * 0.8, lightWidth / 2, lightHeight * 0.8);
            ctx.beginPath();
            ctx.arc(canvas.width - 20 - lightWidth / 2, yPos - lightHeight * 0.8, 20, 0, Math.PI * 2);
            ctx.fillStyle = 'rgba(255, 223, 186, 0.15)';
            ctx.fill();
            ctx.fillStyle = 'yellow';
            ctx.fillRect(canvas.width - 18 - lightWidth/2 -5 , yPos - lightHeight * 0.8 -5, 10, 10);
        }
    }

    function drawObstacles() {
        obstacles.forEach(obs => {
            ctx.fillStyle = obs.color;
            ctx.fillRect(obs.x, obs.y, obs.width, obs.height);
            // Add a slight neon border to obstacles
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 1;
            ctx.strokeRect(obs.x, obs.y, obs.width, obs.height);
        });
    }

    function clearCanvas() {
        // Clear with a transparent or the base background color
        // The container already has the gradient, so clearing to transparent works.
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }

    // --- GAME OVER ---
    function triggerGameOver() {
        gameOver = true;
        gameRunning = false;
        stopEngineSound();
        playCrashSound();
        stopBackgroundMusic(); // Or let it play through game over screen

        finalScoreDisplay.textContent = score;
        finalDistanceDisplay.textContent = Math.floor(distance) + 'm';
        gameOverScreen.style.display = 'flex';

        // Animate game over text (CSS animation 'shakeGameOver' is already applied)
        const gameOverText = gameOverScreen.querySelector('.game-over-text');
        gameOverText.style.animation = 'none'; // Reset animation
        void gameOverText.offsetWidth; // Trigger reflow
        gameOverText.style.animation = 'shakeGameOver 0.5s ease-in-out';

        cancelAnimationFrame(animationFrameId); // Stop the game loop
    }

    // --- GAME LOOP ---
    function gameLoop() {
        if (gameOver) return; // Should be handled by cancelAnimationFrame too

        clearCanvas();

        // Update game state
        if (gameRunning) {
            updateCarPosition();
            updateRoadLines();
            updateStars();
            // updateStreetlights(); // If you implement dynamic ones
            updateObstacles();
            checkCollisions(); // Must be after updating positions
            updateGameSpeed();
        }

        // Draw elements
        drawStars(); // Draw stars first (background)
        drawStreetlights(); // Draw streetlights over stars but behind road
        drawRoadLines();
        drawCar();
        drawObstacles();


        if (gameRunning) {
            animationFrameId = requestAnimationFrame(gameLoop);
        }
    }


    // --- EVENT LISTENERS ---
    startButton.addEventListener('click', () => {
        if (carImage && carImage.complete) { // Ensure car image is loaded
            initGame();
        } else {
            console.warn("Assets not yet loaded. Please wait.");
            // Optionally, show a message to the user
        }
    });

    retryButton.addEventListener('click', () => {
        // Ensure assets are still considered loaded
        if (carImage && carImage.complete) {
            initGame();
        } else {
            // This case should ideally not happen if assets loaded once
            preloadAssets(); // Attempt to reload or re-verify
            alert("Reloading assets. Please wait and try again.");
        }
    });

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    // Touch controls for swipe (on canvas or game container)
    gameContainer.addEventListener('touchstart', handleTouchStart, { passive: false });
    gameContainer.addEventListener('touchmove', handleTouchMove, { passive: false });
    gameContainer.addEvent
