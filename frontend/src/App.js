import React from 'react'
import './App.css';

function App() {
  return (
    <div className="App">
      <div className="particles">
        {[...Array(20)].map((_, i) => (
          <div key={i} className="particle" style={{
            left: `${Math.random() * 100}%`,
            animationDelay: `${Math.random() * 8}s`,
            animationDuration: `${6 + Math.random() * 6}s`
          }}></div>
        ))}
      </div>
      <div className="hero">
        <div className="crown">♛</div>
        <h1 className="title">Winners Never Quit</h1>
        <div className="divider">
          <span className="divider-line"></span>
          <span className="divider-diamond">◆</span>
          <span className="divider-line"></span>
        </div>
        <h2 className="subtitle">Quitters Never Win</h2>
        <p className="tagline">Stay the course. Trust the process. Embrace the grind.</p>
        <div className="stats">
          <div className="stat">
            <span className="stat-number">100%</span>
            <span className="stat-label">Commitment</span>
          </div>
          <div className="stat-divider"></div>
          <div className="stat">
            <span className="stat-number">0%</span>
            <span className="stat-label">Excuses</span>
          </div>
          <div className="stat-divider"></div>
          <div className="stat">
            <span className="stat-number">∞</span>
            <span className="stat-label">Resilience</span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
