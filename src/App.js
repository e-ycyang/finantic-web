import React, { useState } from 'react';
import './App.css';
import Typewriter from './components/Typewriter';

function App() {
  const [showEmail, setShowEmail] = useState(false);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  
  const taglines = [
    "The AI-native investor intelligence platform.",
    "Bloomberg terminal for the AI era.",
    "From idea to conviction in minutes.",
    "Intelligent AI agent for the intelligent investor.",
    "Insight without the institutional overhead.",
    "Know the business—not just the balance sheet.",
    "Where qualitative context meets quantitative clarity."
  ];
  
  const waitlistTagline = ["Join the waitlist."];

  const handleMouseEnter = () => {
    setShowEmail(true);
  };

  const handleMouseLeave = () => {
    if (!email && !name) {
      setShowEmail(false);
    }
  };

  const handleEmailChange = (e) => {
    setEmail(e.target.value);
  };
  
  const handleNameChange = (e) => {
    setName(e.target.value);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    
    // Only process the form if there's actually data
    if (name.trim() || email.trim()) {
      // Send data to server
      fetch('http://localhost:5000/api/waitlist', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name, email }),
      })
        .then(response => response.json())
        .then(data => {
          console.log('Success:', data);
          // Optional: reset the form
          setName('');
          setEmail('');
          setShowEmail(false);
        })
        .catch((error) => {
          console.error('Error:', error);
          // Handle error (could show an error message to the user)
        });
    }
    
    // If fields are empty, do nothing - no validation popup will show
  };

  return (
    <div className="app">
      <div className="landing-container">
        <div 
          className="logo-container" 
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
        >
          {!showEmail ? (
            <img 
              src={`${process.env.PUBLIC_URL}/images/Finantic.png`} 
              alt="Finantic Logo" 
              className="logo" 
            />
          ) : (
            <form onSubmit={handleSubmit} className="email-form">
              <div className="input-group">
                <input
                  type="text"
                  value={name}
                  onChange={handleNameChange}
                  placeholder="Your name"
                  className="name-input"
                  autoFocus
                />
                <input
                  type="email"
                  value={email}
                  onChange={handleEmailChange}
                  placeholder="Your email"
                  className="email-input"
                />
              </div>
              <button type="submit" className="submit-button">
              </button>
            </form>
          )}
        </div>
        <h1 className="tagline">
          <Typewriter phrases={showEmail ? waitlistTagline : taglines} resetOnPhraseChange={true} />
        </h1>
      </div>
    </div>
  );
}

export default App; 