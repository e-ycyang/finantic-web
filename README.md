# Finantic Landing Page

A simple landing page for Finantic showing a coming soon message.

## Setup and Running

1. Navigate to the project directory:
   ```
   cd finantic-landing
   ```

2. Install the dependencies:
   ```
   npm install
   ```

3. Add your logo:
   - Place your "Finantic.png" logo file in the `public` folder.

4. Start the development server:
   ```
   npm start
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Building for Production

To create a production build:
```
npm run build
```

The build files will be in the `build` folder. 

## Deploying to GitHub Pages

To deploy the website to GitHub Pages:

1. Make sure your repository is set up correctly:
   - Check that the `homepage` field in `package.json` matches your GitHub Pages URL
   - Ensure you have GitHub Pages enabled in your repository settings

2. Deploy with a single command:
   ```
   npm run deploy
   ```

3. Your site will be available at: https://ethanyang.github.io/finantic-web 