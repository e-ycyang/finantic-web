import React, { useState, useEffect, useRef } from 'react';

const Typewriter = ({ phrases, resetOnPhraseChange = false }) => {
  const [displayText, setDisplayText] = useState('');
  const [currentPhraseIndex, setCurrentPhraseIndex] = useState(0);
  const [isTyping, setIsTyping] = useState(true);
  const [isPaused, setIsPaused] = useState(false);
  
  // Ref to track previous phrases for comparison
  const previousPhrasesRef = useRef(phrases);

  // Refs for timeout IDs to properly clean up
  const timeoutRef = useRef(null);

  // Function to get a random typing delay to create organic feel
  const getRandomTypingDelay = () => Math.floor(Math.random() * 50) + 50; // 50-100ms
  const getRandomEraseDelay = () => Math.floor(Math.random() * 30) + 20; // 20-50ms
  const pauseDelay = 1500; // Pause delay in ms
  
  // Reset typing state when phrases change
  useEffect(() => {
    if (resetOnPhraseChange && 
        (phrases.length !== previousPhrasesRef.current.length || 
         phrases[0] !== previousPhrasesRef.current[0])) {
      
      // Clear any existing timeouts
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
      
      // Reset state
      setDisplayText('');
      setCurrentPhraseIndex(0);
      setIsTyping(true);
      setIsPaused(false);
    }
    
    // Update ref with current phrases
    previousPhrasesRef.current = phrases;
  }, [phrases, resetOnPhraseChange]);

  useEffect(() => {
    // Clean up any existing timeout
    const cleanUp = () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };

    // In paused state, just wait before continuing
    if (isPaused) {
      timeoutRef.current = setTimeout(() => {
        setIsPaused(false);
        // If we were just typing, now start erasing
        if (isTyping) {
          setIsTyping(false);
        } else {
          // Move to the next phrase after erasing is done
          setCurrentPhraseIndex((prevIndex) => (prevIndex + 1) % phrases.length);
          setIsTyping(true);
        }
      }, pauseDelay);
      return cleanUp;
    }

    const currentPhrase = phrases[currentPhraseIndex];
    
    // Typing phase
    if (isTyping) {
      if (displayText.length < currentPhrase.length) {
        // Still typing
        timeoutRef.current = setTimeout(() => {
          setDisplayText(currentPhrase.substring(0, displayText.length + 1));
        }, getRandomTypingDelay());
      } else {
        // Finished typing, go to pause state
        setIsPaused(true);
      }
    } 
    // Erasing phase
    else {
      if (displayText.length > 0) {
        // Still erasing
        timeoutRef.current = setTimeout(() => {
          setDisplayText(currentPhrase.substring(0, displayText.length - 1));
        }, getRandomEraseDelay());
      } else {
        // Finished erasing, go to pause state
        setIsPaused(true);
      }
    }

    return cleanUp;
  }, [displayText, currentPhraseIndex, isTyping, isPaused, phrases]);

  return (
    <div className="typewriter">
      <span>{displayText}</span>
      <span className="cursor">|</span>
    </div>
  );
};

export default Typewriter; 